require 'aws-sdk-core'
require 'autostacker24'
require 'base64'

require_relative 'configuration'
require_relative 'canarystack'

module AutoCanary24

  class Client
    def initialize(**params)
      @configuration = Configuration.new(params) #params.fetch(:configuration, Configuration::new(params))
    end

    def deploy_stack(parent_stack_name, template, parameters, tags = nil, deployment_check = lambda { |servers| true })
      begin
        puts "AC24: starting to deploy #{parent_stack_name}"
        puts "Using the following configuration #{@configuration.scaling_instance_percent}"

        elb = get_elb(parent_stack_name)
        raise "No ELB found in stack #{parent_stack_name}" if elb.nil?

        blue_cs = get_canary_stack("#{parent_stack_name}-B")
        green_cs = get_canary_stack("#{parent_stack_name}-G")

        stacks = get_stacks_to_create_and_to_delete_for(blue_cs, green_cs, elb)

        puts 'Before switch'
        before_switch(stacks, template, parameters, parent_stack_name, tags)

        puts 'Switch'
        failed = switch(stacks, elb, deployment_check)

        puts 'After switch'
        after_switch(stacks, failed || @configuration.keep_inactive_stack)

      rescue Exception => e
        puts e
      end
    end

    # private
    def get_stacks_to_create_and_to_delete_for(blue_cs, green_cs, elb)

      if green_cs.is_attached_to(elb)
        puts "Green stack is attached to ELB #{elb}, blue will be created, green will be deleted."
        stack_to_delete = green_cs
        stack_to_create = blue_cs
      elsif blue_cs.is_attached_to(elb)
        puts "Blue stack is attached to ELB #{elb}, green will be created, blue will be deleted."
        stack_to_delete = blue_cs
        stack_to_create = green_cs
      else
        puts "No stack is attached to ELB #{elb}, blue will be created."
        stack_to_delete = nil
        stack_to_create = blue_cs
      end

      {stack_to_create: stack_to_create, stack_to_delete: stack_to_delete}
    end

    def before_switch(stacks, template, parameters, parent_stack_name, tags)

      create_stack(stacks[:stack_to_create].stack_name, template, parameters, parent_stack_name, tags)

      unless stacks[:stack_to_delete].nil?
        desired = stacks[:stack_to_delete].get_desired_capacity
        stacks[:stack_to_create].set_desired_capacity_and_wait(desired)
        stacks[:stack_to_delete].suspend_asg_processes
      end

      stacks[:stack_to_create].suspend_asg_processes

    end

    def switch(stacks, elb, deployment_check = nil)

      desired = stacks[:stack_to_create].get_desired_capacity

      instances_to_toggle = (desired / 100.0 * @configuration.scaling_instance_percent).round
      instances_to_toggle = 1 if (instances_to_toggle < 1)

      instances_to_create = stacks[:stack_to_create].get_instance_ids
      instances_to_delete = stacks[:stack_to_delete].nil? ? [] : stacks[:stack_to_delete].get_instance_ids

      missing = desired
      while (missing > 0)

        puts "Adding #{instances_to_toggle} instances (#{desired-missing+instances_to_toggle}/#{desired})"

        begin
          stacks[:stack_to_create].attach_instances_to_elb_and_wait(elb, instances_to_create[desired-missing, instances_to_toggle])
        rescue
          rollback(stacks, elb, instances_to_create, instances_to_delete)
          return true
        end

        if !(deployment_check.call(stacks, elb, instances_to_create))
          rollback(stacks, elb, instances_to_create, instances_to_delete)
          return true
        end

        if @configuration.keep_instances_balanced && !stacks[:stack_to_delete].nil?
          stacks[:stack_to_delete].detach_instances_from_elb(elb, instances_to_delete[desired-missing, instances_to_toggle])
        end

        missing -= instances_to_toggle
        if missing < instances_to_toggle
          instances_to_toggle = missing
        end
      end

      stacks[:stack_to_create].attach_asg_to_elb_and_wait(elb)
      stacks[:stack_to_delete].detach_asg_from_elb_and_wait(elb) unless stacks[:stack_to_delete].nil?
    end

    def rollback(stacks, elb, instances_to_create, instances_to_delete)
      begin
        stacks[:stack_to_create].detach_instances_from_elb(elb, instances_to_create)
        stacks[:stack_to_delete].attach_instances_to_elb_and_wait(elb, instances_to_delete)
      rescue Exception => e
        puts "ROLLBACK FAILED: #{e}"
      end
    end

    def after_switch(stacks, keep_inactive_stack)
      stacks[:stack_to_create].resume_asg_processes
      stacks[:stack_to_delete].resume_asg_processes unless stacks[:stack_to_delete].nil?

      if keep_inactive_stack == false
        delete_stack(stacks[:stack_to_delete])
      end
    end

    def get_elb(stack_name)
      get_first_resource_id(stack_name, 'AWS::ElasticLoadBalancing::LoadBalancer')
    end

    def get_first_resource_id(stack_name, resource_type)
      return nil if stack_name.nil?

      client = Aws::CloudFormation::Client.new
      resp = client.list_stack_resources({ stack_name: stack_name }).data.stack_resource_summaries

      resource_ids = resp.select{|x| x[:resource_type] == resource_type }.map { |e| e.physical_resource_id }
      resource_ids[0]
    end

    def create_stack(stack_name, template, parameters, parent_stack_name, tags = nil)
      puts "create_stack"
      Stacker.create_or_update_stack(stack_name, template, parameters, parent_stack_name, tags)
    end

    def delete_stack(stack_name)
      Stacker.delete_stack(stack_name) unless stack_name.nil?
    end

    private
    def get_canary_stack(stack_name)
      CanaryStack.new(stack_name, @configuration.wait_timeout)
    end
  end

end

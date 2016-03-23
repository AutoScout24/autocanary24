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

    def deploy_stack(parent_stack_name, template, parameters, tags = nil)
      begin
        puts "AC24: starting to deploy #{parent_stack_name}"
        puts "Using the following configuration #{@configuration}"

        elb = get_elb(parent_stack_name)
        raise "No ELB found in stack #{parent_stack_name}" if elb.nil?

        blue_cs = CanaryStack.new("#{parent_stack_name}-B")
        green_cs = CanaryStack.new("#{parent_stack_name}-G")

        stacks = get_stacks_to_create_and_to_delete_for(blue_cs, green_cs, elb)

        puts 'Before switch'
        before_switch(stacks, template, parameters, parent_stack_name, tags)

        puts 'Switch'
        switch(stacks, elb)

        puts 'After switch'
        after_switch(stacks, @configuration.keep_inactive_stack)

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

      desired = stacks[:stack_to_delete].get_desired_capacity
      stacks[:stack_to_create].set_desired_capacity_and_wait(desired)

      stacks[:stack_to_create].suspend_asg_processes
      stacks[:stack_to_delete].suspend_asg_processes
    end

    def switch(stacks, elb)

      desired = stacks[:stack_to_delete].get_desired_capacity()
      instances_to_toggle = (desired / 100.0 * @configuration.scaling_instance_percent).round
      instances_to_toggle = 1 if (instances_to_toggle < 1)

      missing = desired
      while (missing > 0)

        puts "Adding #{instances_to_toggle} instances (#{desired-missing+instances_to_toggle}/#{desired})"

        stacks[:stack_to_create].attach_instances_to_elb_and_wait(elb, instances_to_toggle)

        if @configuration.keep_instances_balanced
          stacks[:stack_to_delete].detach_instances_from_elb_and_wait(elb, instances_to_toggle)
        end

        missing -= instances_to_toggle
        if missing < instances_to_toggle
          instances_to_toggle = missing
        end
      end

      stacks[:stack_to_create].attach_asg_to_elb(elb)
      stacks[:stack_to_delete].detach_asg_from_elb(elb)
    end

    def after_switch(stacks, keep_inactive_stack)
      stacks[:stack_to_create].resume_asg_processes
      stacks[:stack_to_delete].resume_asg_processes

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
      Stacker.delete_stack(stack_name)
    end

  end

end

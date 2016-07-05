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

    def deploy_stack(parent_stack_name, template, parameters, tags = nil, deployment_check = lambda { |stacks, elb, new_attached_instances| true })
      begin
        write_log(parent_stack_name, "Starting the deployment")
        write_log(parent_stack_name, "Using the following configuration #{@configuration.inspect}")

        elb = get_elb(parent_stack_name)
        raise "No ELB found in stack #{parent_stack_name}" if elb.nil?

        blue_cs = get_canary_stack("#{parent_stack_name}-B")
        green_cs = get_canary_stack("#{parent_stack_name}-G")

        stacks = get_stacks_to_create_and_to_delete_for(blue_cs, green_cs, elb)

        before_switch(stacks, template, parameters, parent_stack_name, tags)

        failed = switch(stacks, elb, deployment_check)

        after_switch(stacks, failed || @configuration.keep_inactive_stack)

      rescue Exception => e
        write_log(parent_stack_name, "Unexpected exception #{e}")
        raise "Deployment failed"
      end

      if failed
        raise "Deployment failed because of rollback"
      else
        write_log(parent_stack_name, "Deployment finished")
      end

    end

    private
    def get_stacks_to_create_and_to_delete_for(blue_cs, green_cs, elb)

      green_is_attached = green_cs.is_attached_to(elb)
      blue_is_attached = blue_cs.is_attached_to(elb)

      if green_is_attached
        stack_to_delete = green_cs
        stack_to_create = blue_cs
      elsif blue_is_attached
        stack_to_delete = blue_cs
        stack_to_create = green_cs
      else
        stack_to_delete = nil
        stack_to_create = blue_cs
      end

      write_log(blue_cs.stack_name, blue_is_attached ? "Stack is attached to ELB #{elb}" : "Stack is not attached")
      write_log(green_cs.stack_name, green_is_attached ? "Stack is attached to ELB #{elb}" : "Stack is not attached")

      write_log(stack_to_create.stack_name, "will be created")
      write_log(stack_to_delete.stack_name, "will be deleted") unless stack_to_delete.nil?

      {stack_to_create: stack_to_create, stack_to_delete: stack_to_delete}
    end

    def before_switch(stacks, template, parameters, parent_stack_name, tags)

      create_stack(stacks[:stack_to_create].stack_name, template, parameters, parent_stack_name, tags)

      unless stacks[:stack_to_delete].nil?
        current_desired_capacity = stacks[:stack_to_delete].get_desired_capacity
        write_log(stacks[:stack_to_delete].stack_name, "Found #{current_desired_capacity} instances")

        to_create_desired_capacity = stacks[:stack_to_create].get_desired_capacity
        if current_desired_capacity > to_create_desired_capacity
          write_log(stacks[:stack_to_create].stack_name, "Will set DesiredCapacity to #{current_desired_capacity}")
          stacks[:stack_to_create].set_desired_capacity_and_wait(current_desired_capacity)
        end
        stacks[:stack_to_delete].suspend_asg_processes
      end

      stacks[:stack_to_create].suspend_asg_processes

    end

    def switch(stacks, elb, deployment_check)

      desired = stacks[:stack_to_create].get_desired_capacity

      instances_to_toggle = (desired / 100.0 * @configuration.scaling_instance_percent).round
      instances_to_toggle = 1 if (instances_to_toggle < 1)

      instances_to_attach = stacks[:stack_to_create].get_instance_ids
      write_log(stacks[:stack_to_create].stack_name, "Instances to attach: #{instances_to_attach}")

      instances_to_detach = stacks[:stack_to_delete].nil? ? [] : stacks[:stack_to_delete].get_instance_ids
      write_log(stacks[:stack_to_delete].stack_name, "Instances to detach: #{instances_to_detach}") unless stacks[:stack_to_delete].nil?

      missing = desired
      while missing > 0

        write_log(stacks[:stack_to_create].stack_name, "Adding #{instances_to_toggle} instances (#{instances_to_attach[desired-missing, instances_to_toggle]})")

        already_attached_instances = instances_to_attach[0, desired-missing+instances_to_toggle]
        already_detached_instances = instances_to_detach[0, desired-missing]

        begin
          stacks[:stack_to_create].attach_instances_to_elb_and_wait(elb, instances_to_attach[desired-missing, instances_to_toggle])
        rescue Exception => e
          write_log(stacks[:stack_to_create].stack_name, "Unexpected exception: #{e}")
          rollback(stacks, elb, already_attached_instances, already_detached_instances)
          return true
        end

        unless deployment_check.call(stacks, elb, already_attached_instances)
          rollback(stacks, elb, already_attached_instances, already_detached_instances)
          return true
        end

        if @configuration.keep_instances_balanced && !stacks[:stack_to_delete].nil?
          begin
            write_log(stacks[:stack_to_delete].stack_name, "Removing #{instances_to_toggle} instances (#{instances_to_detach[desired-missing, instances_to_toggle]})")
            stacks[:stack_to_delete].detach_instances_from_elb(elb, instances_to_detach[desired-missing, instances_to_toggle])
          rescue Exception => e
            write_log(stacks[:stack_to_delete].stack_name, "WARNING: #{e}")
          end
        end

        missing -= instances_to_toggle
        if missing < instances_to_toggle
          instances_to_toggle = missing
        end
      end

      write_log(stacks[:stack_to_create].stack_name, "Attach to ELB #{elb}")
      stacks[:stack_to_create].attach_asg_to_elb_and_wait(elb)

      unless stacks[:stack_to_delete].nil?
        write_log(stacks[:stack_to_delete].stack_name, "Detach from ELB #{elb}")
        stacks[:stack_to_delete].detach_asg_from_elb_and_wait(elb)
      end
    end

    def rollback(stacks, elb, already_attached_instances, already_detached_instances)
      write_log("", "Rollback triggered")
      begin
        stacks[:stack_to_create].detach_instances_from_elb(elb, already_attached_instances)
        stacks[:stack_to_delete].attach_instances_to_elb_and_wait(elb, already_detached_instances) unless stacks[:stack_to_delete].nil?
      rescue Exception => e
        write_log("", "ROLLBACK FAILED: #{e}")
      end
    end

    def after_switch(stacks, keep_inactive_stack)
      stacks[:stack_to_create].resume_asg_processes

      unless stacks[:stack_to_delete].nil?
        stacks[:stack_to_delete].resume_asg_processes

        unless keep_inactive_stack
          delete_stack(stacks[:stack_to_delete].stack_name)
        end
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

    def create_stack(stack_name, template, parameters, parent_stack_name, tags)
      write_log(stack_name, "Create/Update stack")
      Stacker.create_or_update_stack(stack_name, template, parameters, parent_stack_name, tags, @configuration.wait_timeout)
    end

    def delete_stack(stack_name)
      Stacker.delete_stack(stack_name, @configuration.wait_timeout) unless stack_name.nil?
    end

    def get_canary_stack(stack_name)
      CanaryStack.new(stack_name, @configuration.wait_timeout)
    end

    def write_log(stack_name, message)
      puts "#{Time.now.utc}\t#{stack_name.ljust(20)}\t#{message.ljust(40)}"
    end
  end

end

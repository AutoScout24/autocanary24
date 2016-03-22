require 'aws-sdk-core'
require 'autostacker24'
require 'base64'
require_relative 'configuration'
require_relative 'canarystack'

module AutoCanary24

  class Client
    def initialize(**params)
      @configuration = AutoCanary24::Configuration.new(params) #params.fetch(:configuration, Configuration::new(params))
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
        after_switch(stacks[:stack_to_delete], @configuration.keep_inactive_stack)

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
        stack_to_create = blue_cs
      end

      return {stack_to_create: stack_to_create, stack_to_delete: stack_to_delete}
    end

    def before_switch(stacks, template, parameters, parent_stack_name, tags)

      create_stack(stacks[:stack_to_create].stack_name, template, parameters, parent_stack_name, tags)

      desired = stacks[:stack_to_delete].get_desired_capacity
      stacks[:stack_to_create].set_desired_capacity_and_wait(desired)
    end

    def switch(stacks, elb)

      stacks[:stack_to_create].attach_to_elb_and_wait(elb)
      stacks[:stack_to_delete].detach_from_elb_and_wait(elb)

      # TODO consider @configuration.scaling_instance_percent
      # instances_to_create_per_step = desired
      # instances_to_delete_per_step = desired if @configuration.keep_instances_balanced

      # created_instances = 0
      # while created_instances < desired
      #
      #   # Add n new instances, wait until they are
      #   # Wait until instances are healthy
      #   # Attach them to elb
      #   attach_instances(stack_to_create, instances_to_create_per_step, elb)
      #
      #   if instances_to_delete_per_step > 0
      #     # Detach n instances from elb
      #     detach_instances(stack_to_delete, instances_to_delete_per_step, elb)
      #   end
      #
      #   created_instances += instances_to_create_per_step
      #
      #   missing = desired - created_instances
      #   if missing < instances_to_create
      #     instances_to_create = missing
      #   end
      # end
    end

    def after_switch(stack_to_delete, keep_inactive_stack)
      if keep_inactive_stack == false
        delete_stack(stack_to_delete)
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

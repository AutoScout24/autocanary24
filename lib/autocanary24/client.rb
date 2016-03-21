require 'aws-sdk-core'
require 'autostacker24'
require 'base64'

module AutoCanary24

  class Client
    def initialize(**params)
      # @configuration = params[:configuration].nil ? Configuration::new : params[:configuration]
    end

    def get_stacks_to_create_and_to_delete_for(stack_name, elb)

      stack_blue = "#{stack_name}-B"
      stack_green = "#{stack_name}-G"

      green_elbs = blue_elbs = []
      if find_stack(stack_green)
        puts "found green"
        green_asg = get_autoscaling_group(stack_green)
        green_elbs = get_attached_loadbalancers(green_asg) unless green_asg.nil?
      end

      if find_stack(stack_blue)
        puts "found blue"
        blue_asg = get_autoscaling_group(stack_blue)
        blue_elbs = get_attached_loadbalancers(blue_asg) unless blue_asg.nil?
      end

      to_delete = nil
      stack_name_to_create = stack_blue

      if (green_elbs.any? { |e| e.load_balancer_name == elb })
        puts "Green stack is attached to ELB #{elb}, blue will be created, green will be deleted."
        stack_name_to_delete = stack_green
        stack_name_to_create = stack_blue
      elsif (blue_elbs.any? { |e| e.load_balancer_name == elb })
        puts "Blue stack is attached to ELB #{elb}, green will be created, blue will be deleted."
        stack_name_to_delete = stack_blue
        stack_name_to_create = stack_green
      else
        puts "No stack is attached to ELB #{elb}, blue will be created."
      end

      return {stack_name_to_create: stack_name_to_create, stack_name_to_delete: stack_name_to_delete}
    end

    def deploy_stack(stack_name, template, parameters, parent_stack_name, tags = nil)
      begin
        puts "AC24: starting to deploy #{stack_name}"

        elb = get_elb(parent_stack_name)
        raise "No ELB found in stack #{parent_stack_name}" if elb.nil?

        stacks = get_stacks_to_create_and_to_delete_for(stack_name, elb)

        # before_switch
        before_switch(stacks, template, parameters, parent_stack_name, tags)

        # Blue/Green (switch)
        switch(stacks, elb)

        # After switch
        after_switch(stacks[:stack_name_to_delete], @configuration.keep_inactive_stack)

      rescue Exception => e
        puts e
      end
    end

    def before_switch(stacks, template, parameters, parent_stack_name, tags)

      # Find out current desired count
      desired = get_desired_count(stacks[:stack_name_to_delete])

      create_stack(stacks[:stack_name_to_create], template, parameters, parent_stack_name, tags)

      set_desired_count(stacks[:stack_name_to_create], desired)
    end

    def switch(stacks, elb)
      asg_to_create = get_autoscaling_group(stacks[:stack_name_to_create])
      asg_to_delete = get_autoscaling_group(stacks[:stack_name_to_delete])

      attach_asg_to_elb(asg_to_create, elb)
      wait_for_instances(asg_to_create, elb)
      detach_asg_from_elb(asg_to_delete, elb)
    end

        # TODO consider @configuration.scaling_instance_percent
        # instances_to_create_per_step = desired
        # instances_to_delete_per_step = desired if @configuration.keep_instances_balanced

        # created_instances = 0
        # while created_instances < desired
        #
        #   # Add n new instances, wait until they are
        #   # Wait until instances are healthy
        #   # Attach them to elb
        #   attach_instances(stack_name_to_create, instances_to_create_per_step, elb)
        #
        #   # TODO: Shall we wait? @configuration.scaling_wait_interval
        #
        #   if instances_to_delete_per_step > 0
        #     # Detach n instances from elb
        #     detach_instances(stack_name_to_delete, instances_to_delete_per_step, elb)
        #   end
        #
        #   created_instances += instances_to_create_per_step
        #
        #   missing = desired - created_instances
        #   if missing < instances_to_create
        #     instances_to_create = missing
        #   end
        # end

    def after_switch(stack_name_to_delete, keep_inactive_stack)
      if keep_inactive_stack == false
        delete_stack(stack_name_to_delete)
      end
    end

    def get_desired_count(stack_name)
    end

    def set_desired_count(stack_name, desired_count)
    end

    def get_elb(stack_name)
      client = Aws::CloudFormation::Client.new

      resp = client.list_stack_resources({
        stack_name: stack_name
      })

      elbs = resp.data.stack_resource_summaries.select{|x| x[:resource_type] == "AWS::ElasticLoadBalancing::LoadBalancer" }.map { |e| e.physical_resource_id  }

      elbs[0]
    end

    def get_autoscaling_group(stack_name)
      client = Aws::CloudFormation::Client.new

      resp = client.list_stack_resources({
        stack_name: stack_name
      })

      asgs = resp.data.stack_resource_summaries.select{|x| x[:resource_type] == "AWS::AutoScaling::AutoScalingGroup" }.map { |e| e.physical_resource_id  }

      asgs[0]
    end

    def get_attached_loadbalancers(asg)
      puts "get_attached_loadbalancers"
      asg_client = Aws::AutoScaling::Client.new
      asg_client.describe_load_balancers({ auto_scaling_group_name: asg }).load_balancers
    end

    def create_stack(stack_name, template, parameters, parent_stack_name, tags = nil)
      puts "create_stack"
      Stacker.create_or_update_stack(stack_name, template, parameters, parent_stack_name, tags)
    end

    def delete_stack(stack_name)
      STACKER.delete_stack(stack_name)
    end

    def find_stack(stack_name)
      puts "find_stack"
      Stacker.find_stack(stack_name)
    end

    def detach_asg_from_elb(asg, elb)
      puts "detach_load_balancers"
    end

    def attach_asg_to_elb(asg, elb)
      puts "attach_load_balancers"
      asg_client = Aws::AutoScaling::Client.new
      asg_client.attach_load_balancers({auto_scaling_group_name: asg, load_balancer_names: [elb]})
    end

    # def rollback (stack_to_rollback, failed_stack, elb)
    #
    #   # # Rollback: reattach the old ASG and delete the newly created stack
    #   # asg_to_rollback = get_autoscaling_group(stack_to_rollback)
    #   # attach_load_balancers(asg_to_rollback, elb)
    #   # wait_for_instances(asg_to_rollback,elb)
    #   #
    #   # delete_asg_stack(failed_stack,elb)
    #
    # end

    def wait_for_instances(asg, elb)
      puts "wait_for_instances"

      asg_client = Aws::AutoScaling::Client.new
      instances = asg_client.describe_auto_scaling_groups({auto_scaling_group_names: [asg]})[:auto_scaling_groups][0][:instances].map{ |i| { instance_id: i[:instance_id] } }
      puts "Waiting for the following new instances to get healthy in ELB:"
      instances.map{ |i| puts i[:instance_id] }
      elb_client = Aws::ElasticLoadBalancing::Client.new
      while true
        begin
          elb_instances = elb_client.describe_instance_health({load_balancer_name: elb, instances: instances})
          break if elb_instances[:instance_states].select{ |s| s.state != 'InService' }.length == 0
        rescue Aws::ElasticLoadBalancing::Errors::InvalidInstance
        end
        sleep 5
        # TODO add retry limit and think about what to do then
      end

      puts "All new instances are healthy now"
    end

  end

  class StackState
    def self.INSERVICE
      'INSERVICE'
    end
    def self.STANDBY
      'STANDBY'
    end
    def self.TERMINATE
      'TERMINATE'
    end
  end

  class Configuration
    # Defines what should happen with the inactive stack
    attr_accessor :inactive_stack_state
    # Wait time until the inactive_stack_state is applied to the inactive stack (will be ignored when inactive_stack_state is inService)
    attr_accessor :inactive_stack_state_after
    # If true a instance from current stack gets removed whenever a new instance from the new stack is added.
    attr_accessor :keep_instances_balanced
    # Percent of instances which are added at once (depends on the actual number of instances, read from desired)
    attr_accessor :scaling_instance_percent
    # Wait time before the next instances are added
    attr_accessor :scaling_wait_interval

    def initialize

      @inactive_stack_state = StackState.TERMINATE
      unless params[:inactive_stack_state].nil
        raise "ERR: inactive_stack_state should be of type StackState" unless params[:inactive_stack_state].is_a?(StackState)
        @inactive_stack_state = params[:inactive_stack_state]
      end

      # initialize with some defaults
      @inactive_stack_state_after = nil
      unless params[:inactive_stack_state_after].nil
        raise 'ERR: inactive_stack_state_after needs to a number' unless params[:inactive_stack_state_after].is_a?(Integer)
        @inactive_stack_state_after = params[:inactive_stack_state_after]
      end

      @keep_instances_balanced = false
      unless params[:keep_instances_balanced].nil
        raise 'ERR: keep_instances_balanced needs to a boolean' unless params[:keep_instances_balanced].is_a?(Bool)
        @keep_instances_balanced = params[:keep_instances_balanced]
      end

      @scaling_instance_percent = 100
      unless params[:scaling_instance_percent].nil
        raise 'ERR: scaling_instance_percent needs to be a number between 1 and 100' unless params[:scaling_instance_percent].is_a?(Integer) && (1..100).include?(params[:scaling_instance_percent])
        @scaling_instance_percent = params[:scaling_instance_percent]
      end

      @scaling_wait_interval = nil
      unless params[:scaling_wait_interval].nil
        raise 'ERR: scaling_wait_interval needs to a number' unless params[:scaling_wait_interval].is_a?(Integer)
        @scaling_wait_interval = params[:scaling_wait_interval]
      end
    end

  end

end

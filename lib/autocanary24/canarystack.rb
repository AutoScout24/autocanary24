require 'aws-sdk-core'
require 'aws-sdk-elasticloadbalancing'

module AutoCanary24
  class CanaryStack
    attr_reader :stack_name

    def initialize(stack_name, wait_timeout, sleep_during_wait = 5)
      raise "ERR: stack_name is missing" if stack_name.nil?
      raise "ERR: wait_timeout is missing" if wait_timeout.nil?
      @stack_name = stack_name
      @wait_timeout = wait_timeout
      @sleep_during_wait = sleep_during_wait
    end

    def get_desired_capacity
      asg = get_autoscaling_group
      asg_client = Aws::AutoScaling::Client.new
      describe_asg(asg).desired_capacity
    end

    def set_desired_capacity_and_wait(desired_capacity)
      asg = get_autoscaling_group
      asg_client = Aws::AutoScaling::Client.new
      resp = asg_client.set_desired_capacity({
        auto_scaling_group_name: asg,
        desired_capacity: desired_capacity,
        honor_cooldown: false,
      })
      wait_for_instances_in_asg(asg, desired_capacity)
    end

    def is_attached_to(elb)
      asg = get_autoscaling_group
      elbs = get_attached_loadbalancers(asg) unless asg.nil?
      (!elbs.nil? && elbs.any? { |e| e.load_balancer_name == elb && e.state != "Removing" && e.state != "Removed" })
    end

    def attach_instances_to_elb_and_wait(elb, instances)
      elb_client = Aws::ElasticLoadBalancing::Client.new
      elb_client.register_instances_with_load_balancer({ load_balancer_name: elb, instances: instances })
      wait_for_instances_attached_to_elb(instances, elb)
    end

    def detach_instances_from_elb(elb, instances)
      elb_client = Aws::ElasticLoadBalancing::Client.new
      elb_client.deregister_instances_from_load_balancer({ load_balancer_name: elb, instances: instances })
    end

    def detach_asg_from_elb_and_wait(elb)
      asg = get_autoscaling_group
      asg_client = Aws::AutoScaling::Client.new
      asg_client.detach_load_balancers({auto_scaling_group_name: asg, load_balancer_names: [elb]})
      wait_for_asg_detached_from_elb(asg, elb)
    end

    def attach_asg_to_elb_and_wait(elb)
      asg = get_autoscaling_group
      asg_client = Aws::AutoScaling::Client.new
      asg_client.attach_load_balancers({auto_scaling_group_name: asg, load_balancer_names: [elb]})
      wait_for_asg_on_elb(asg, elb)
    end

    def suspend_asg_processes
      processes = ['Launch', 'Terminate', 'AddToLoadBalancer', 'AlarmNotification', 'AZRebalance']
      asg = get_autoscaling_group
      asg_client = Aws::AutoScaling::Client.new
      asg_client.suspend_processes({auto_scaling_group_name: asg, scaling_processes: processes})
    end

    def resume_asg_processes
      processes = ['Launch', 'Terminate', 'AddToLoadBalancer', 'AlarmNotification', 'AZRebalance']
      asg = get_autoscaling_group
      asg_client = Aws::AutoScaling::Client.new
      asg_client.resume_processes({auto_scaling_group_name: asg, scaling_processes: processes})
    end

    def get_instance_ids
      asg = get_autoscaling_group
      asg_client = Aws::AutoScaling::Client.new
      describe_asg(asg)[:instances] \
        .select { |i| i[:lifecycle_state]=="InService" } \
        .map{ |i| { instance_id: i[:instance_id] } }
    end

    def is_stack_created?
      begin
        get_instance_ids
      rescue
        return false
      end
      true
    end

    private
    def describe_asg(asg)
      asg_client = Aws::AutoScaling::Client.new
      asg_client.describe_auto_scaling_groups({auto_scaling_group_names: [asg], max_records: 1})[:auto_scaling_groups][0]
    end

    def wait_for_asg_detached_from_elb(asg, elb)
      auto_scaling_group = describe_asg(asg)

      if auto_scaling_group[:load_balancer_names].select{|l| l == elb}.length == 1
        puts "WARNING: ASG still on the ELB!"
      end

      asg_instances = auto_scaling_group[:instances] \
        .select { |i| i[:lifecycle_state]=="InService" } \
        .map{ |i| { instance_id: i[:instance_id] } }

      elb_client = Aws::ElasticLoadBalancing::Client.new
      elb_instances = elb_client.describe_instance_health({load_balancer_name: elb})[:instance_states] \
        .map{ |i| { instance_id: i[:instance_id] } }

      # Remove instances that are not registered at the ELB
      instances = elb_instances & asg_instances

      if instances.length > 0
        wait_for_instances_detached_from_elb(instances, elb)
      end
    end

    def wait_for_instances_detached_from_elb(instances, elb)
      elb_client = Aws::ElasticLoadBalancing::Client.new
      retries = (@wait_timeout / @sleep_during_wait).round
      while retries > 0
        begin
          elb_instances = elb_client.describe_instance_health({load_balancer_name: elb, instances: instances})
          break if elb_instances[:instance_states].select{ |s| s.state == 'InService' }.length == 0
        rescue Aws::ElasticLoadBalancing::Errors::InvalidInstance
        end
        sleep @sleep_during_wait
        retries -= 1
      end

      raise "Timeout. Couldn't wait for instances '#{instances}' to get detached from ELB '#{elb}'." if retries == 0
    end

    def wait_for_asg_on_elb(asg, elb)
      auto_scaling_group = describe_asg(asg)

      if auto_scaling_group[:load_balancer_names].select{|l| l == elb}.length == 0
        puts "WARNING: ASG not on the ELB yet!"
      end

      instances = auto_scaling_group[:instances] \
        .select { |i| i[:lifecycle_state]=="InService" } \
        .map{ |i| { instance_id: i[:instance_id] } }

      wait_for_instances_attached_to_elb(instances, elb)
    end

    def wait_for_instances_attached_to_elb(instances, elb)
      elb_client = Aws::ElasticLoadBalancing::Client.new
      retries = (@wait_timeout / @sleep_during_wait).round
      while retries > 0
        begin
          elb_instances = elb_client.describe_instance_health({load_balancer_name: elb, instances: instances})
          break if elb_instances[:instance_states].select{ |s| s.state != 'InService' }.length == 0
        rescue Aws::ElasticLoadBalancing::Errors::InvalidInstance
        end
        sleep @sleep_during_wait
        retries -= 1
      end

      raise "Timeout. Couldn't wait for instances '#{instances}' to get attached to ELB '#{elb}'." if retries == 0
    end

    def wait_for_instances_in_asg(asg, expected_number_of_instances)
      asg_client = Aws::AutoScaling::Client.new
      retries = (@wait_timeout / @sleep_during_wait).round
      while retries > 0
        instances = asg_client.describe_auto_scaling_groups({auto_scaling_group_names: [asg]})[:auto_scaling_groups][0].instances
        healthy_instances = instances.select{ |i| i[:health_status] == "Healthy" && i[:lifecycle_state]=="InService"}.length
        break if healthy_instances == expected_number_of_instances
        sleep @sleep_during_wait
        retries -= 1
      end

      raise "Timeout. Only #{healthy_instances} of #{expected_number_of_instances} instances got healthy in ASG '#{asg}'." if retries == 0
    end

    def get_attached_loadbalancers(asg)
      asg_client = Aws::AutoScaling::Client.new
      asg_client.describe_load_balancers({ auto_scaling_group_name: asg }).load_balancers
    end

    def get_autoscaling_group
      get_first_resource_id('AWS::AutoScaling::AutoScalingGroup')
    end

    def get_first_resource_id(resource_type)
      client = Aws::CloudFormation::Client.new
      begin
        response = client.list_stack_resources({ stack_name: @stack_name })
      rescue Exception
        return nil
      end
      resources = response.data.stack_resource_summaries.select{|x| x[:resource_type] == resource_type }
      resources.map{ |e| e.physical_resource_id }[0]
    end
  end
end

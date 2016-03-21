require 'spec_helper'

describe AutoCanary24::Client do
  let(:ac24) { AutoCanary24::Client.new }
  let(:elb) { "ELB-123" }

  context 'Before switch' do
    let(:loadbalancer) { [ Aws::AutoScaling::Types::LoadBalancerState.new(load_balancer_name: elb) ] }

    describe 'when blue is currently active' do
      before do
        allow(ac24).to receive(:find_stack).with('mystack_B').and_return(true)
        allow(ac24).to receive(:find_stack).with('mystack_G').and_return(false)

        allow(ac24).to receive(:get_autoscaling_group).and_return('asg')
        allow(ac24).to receive(:get_attached_loadbalancers).and_return(loadbalancer)
      end

      it 'should activate the green stack' do
        expect(ac24.get_stacks_to_create_and_to_delete_for('mystack', elb)).to eq({stack_name_to_delete: 'mystack_B', stack_name_to_create: 'mystack_G'})
      end
    end

    describe 'when green is currently active' do
      before do
        allow(ac24).to receive(:find_stack).with('mystack_B').and_return(false)
        allow(ac24).to receive(:find_stack).with('mystack_G').and_return(true)

        allow(ac24).to receive(:get_autoscaling_group).and_return('asg')
        allow(ac24).to receive(:get_attached_loadbalancers).and_return(loadbalancer)
      end

      it 'should activate the blue stack' do
        expect(ac24.get_stacks_to_create_and_to_delete_for('mystack', elb)).to eq({stack_name_to_delete: 'mystack_G', stack_name_to_create: 'mystack_B'})
      end
    end

    describe 'when no stack is active' do
      before do
        allow(ac24).to receive(:find_stack).with('mystack_B').and_return(false)
        allow(ac24).to receive(:find_stack).with('mystack_G').and_return(false)
      end

      it 'should activate the blue stack' do
        expect(ac24.get_stacks_to_create_and_to_delete_for('mystack', elb)).to eq({stack_name_to_delete: nil, stack_name_to_create: 'mystack_B'})
      end
    end

    describe 'when desired count of active stack is 5' do
      let(:stacks) { {:stack_name_to_create => 'mystack_B', :stack_name_to_delete => 'mystack_G'} }
      let(:template) { 'template' }
      let(:parameters) { {:para1=>"value"} }
      let(:parent_stack_name) { 'mystack' }
      let(:tags) { [{"Key"=>"MyKey", "Value"=>"MyValue"}] }

      it 'should create the new stack' do
        allow(ac24).to receive(:create_stack)
        allow(ac24).to receive(:get_desired_count).with('mystack_G').and_return(5)
        expect(ac24).to receive(:create_stack).with('mystack_B', template, parameters, parent_stack_name, tags)

        ac24.before_switch(stacks, template, parameters, parent_stack_name, tags)
      end

      it 'should be 5 instances after creation' do

        allow(ac24).to receive(:create_stack)
        allow(ac24).to receive(:get_desired_count).with('mystack_G').and_return(5)
        expect(ac24).to receive(:set_desired_count).with('mystack_B', 5)

        ac24.before_switch(stacks, nil, nil, nil, nil)
      end
    end

  end

  context 'Switch (Blue/Green)' do

    describe 'when switching from Blue to Green stack' do
      let(:stacks) { {:stack_name_to_create => 'mystack_G', :stack_name_to_delete => 'mystack_B'} }

      it 'should attach the ASG from Green stack to the ELB' do
        allow(ac24).to receive(:get_autoscaling_group).with('mystack_G').and_return('ASG_G')
        allow(ac24).to receive(:get_autoscaling_group).with('mystack_B').and_return('ASG_B')
        allow(ac24).to receive(:wait_for_instances)

        expect(ac24).to receive(:attach_asg_to_elb).with('ASG_G', elb)

        ac24.switch(stacks, elb)
      end

      it 'should wait until all instances from Green ASG are marked as healthy in ELB' do
        allow(ac24).to receive(:get_autoscaling_group).with('mystack_G').and_return('ASG_G')
        allow(ac24).to receive(:get_autoscaling_group).with('mystack_B').and_return('ASG_B')

        expect(ac24).to receive(:wait_for_instances).with('ASG_G', elb)

        ac24.switch(stacks, elb)
      end

      it 'should detach the ASG from Blue stack from the ELB' do
        allow(ac24).to receive(:get_autoscaling_group).with('mystack_G').and_return('ASG_G')
        allow(ac24).to receive(:get_autoscaling_group).with('mystack_B').and_return('ASG_B')
        allow(ac24).to receive(:wait_for_instances)

        expect(ac24).to receive(:detach_asg_from_elb).with('ASG_B', elb)

        ac24.switch(stacks, elb)
      end
    end
  end


  # context 'Canary deployment' do
  #   describe 'when desired count of active stack is 5 and scaling_instance_percent is 10' do
  #     it 'should add exactly 1 instances at a time' do
  #       pending
  #     end
  #   end
  #
  #   describe 'when desired count of active stack is 5 and scaling_instance_percent is 50' do
  #     it 'should add 3 instances the first time' do
  #       pending
  #     end
  #     it 'should add 2 instances the second time' do
  #       pending
  #     end
  #   end
  #
  #   describe 'when desired count of active stack is 5 and scaling_instance_percent is 80' do
  #     it 'should add 4 instances the first time' do
  #       pending
  #     end
  #     it 'should add 1 instances the second time' do
  #       pending
  #     end
  #   end
  #
  #   describe 'when new instances are added and scaling_wait_interval is set to 5 sec' do
  #     it 'should wait 5sec after the instances were added' do
  #       pending
  #     end
  #   end
  #   describe 'when keep_instances_balanced is true' do
  #     it 'should remove x instance(s) from current stack after x new instance(s) were added to the new stack' do
  #       pending
  #     end
  #   end
  #
  #   describe 'when keep_instances_balanced is false' do
  #     it 'should not remove instances from current stack after adding new instances to the new stack' do
  #       pending
  #     end
  #     it 'should remove all instances from current stack after adding all instances of the new stack' do
  #       pending
  #     end
  #   end
  #
  # end
  #
  context 'After switch' do
  #   describe 'when the deployment is done' do
  #     it 'should not send traffic to the inactive stack' do
  #       pending
  #     end
  #   end
  #
    describe 'when configuration of keep_inactive_stack is TRUE' do
      it 'should keep the inactive stack' do
        expect(ac24).to receive(:delete_stack).with('mystack').exactly(0).times
        ac24.after_switch('mystack', true)
      end
    end

    describe 'when configuration of keep_inactive_stack is FALSE' do
      it 'should delete the inactive stack' do
        expect(ac24).to receive(:delete_stack).with('mystack')
        ac24.after_switch('mystack', false)
      end
    end
  end

  # context 'Hooks' do
  #   # TODO Support hooks/callbacks to cancel/rollback the deployment (canary release)
  # end
  #
  # context 'Deployment Failures' do
  #   describe 'when new instances dont get healthy' do
  #     it 'should automatically rollback' do
  #       pending
  #     end
  #   end
  # end
  # Both stacks are somehow active
end



  #     it 'should always be 5 or more instances (overall) during deployment' do
  #       pending
  #     end

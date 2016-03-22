require 'spec_helper'

describe AutoCanary24::Client do
  let(:ac24) { AutoCanary24::Client.new }
  let(:elb) { "ELB-123" }
  let(:blue_cs) { AutoCanary24::CanaryStack.new('mystack-B') }
  let(:green_cs) { AutoCanary24::CanaryStack.new('mystack-G') }

  context 'Before switch' do
    let(:loadbalancer) { [ Aws::AutoScaling::Types::LoadBalancerState.new(load_balancer_name: elb) ] }

    describe 'when blue is currently active' do

      before do
        allow(blue_cs).to receive(:is_attached_to).with(elb).and_return(true)
        allow(green_cs).to receive(:is_attached_to).with(elb).and_return(false)
      end

      it 'should activate the green stack' do
        expect(ac24.get_stacks_to_create_and_to_delete_for(blue_cs, green_cs, elb)).to eq({stack_to_delete: blue_cs, stack_to_create: green_cs})
      end
    end

    describe 'when green is currently active' do
      before do
        allow(blue_cs).to receive(:is_attached_to).with(elb).and_return(false)
        allow(green_cs).to receive(:is_attached_to).with(elb).and_return(true)
      end

      it 'should activate the blue stack' do
        expect(ac24.get_stacks_to_create_and_to_delete_for(blue_cs, green_cs, elb)).to eq({stack_to_delete: green_cs, stack_to_create: blue_cs})
      end
    end

    describe 'when no stack is active' do
      before do
        allow(blue_cs).to receive(:is_attached_to).with(elb).and_return(false)
        allow(green_cs).to receive(:is_attached_to).with(elb).and_return(false)
      end

      it 'should activate the blue stack' do
        expect(ac24.get_stacks_to_create_and_to_delete_for(blue_cs, green_cs, elb)).to eq({stack_to_delete: nil, stack_to_create: blue_cs})
      end
    end

    describe 'when desired count of active stack is 5' do
      let(:stacks) { {:stack_to_create => blue_cs, :stack_to_delete => green_cs} }
      let(:template) { 'template' }
      let(:parameters) { {:para1=>"value"} }
      let(:parent_stack_name) { 'mystack' }
      let(:tags) { [{"Key"=>"MyKey", "Value"=>"MyValue"}] }

      it 'should create the new stack' do
        allow(blue_cs).to receive(:set_desired_capacity_and_wait)
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)

        expect(ac24).to receive(:create_stack).with('mystack-B', template, parameters, parent_stack_name, tags)

        ac24.before_switch(stacks, template, parameters, parent_stack_name, tags)
      end

      it 'should be 5 instances after creation' do

        allow(ac24).to receive(:create_stack)
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        expect(blue_cs).to receive(:set_desired_capacity_and_wait).with(5)

        ac24.before_switch(stacks, nil, nil, nil, nil)
      end
    end

  end

  context 'Switch (Blue/Green)' do

    describe 'when switching from Blue to Green stack' do
      let(:stacks) { {:stack_to_create => green_cs, :stack_to_delete => blue_cs} }

      it 'should attach the ASG from Green stack to the ELB' do
        allow(blue_cs).to receive(:get_desired_capacity).and_return(1)
        allow(blue_cs).to receive(:detach_from_elb_and_wait).with(elb)

        expect(green_cs).to receive(:attach_to_elb_and_wait).with(elb, 1)

        ac24.switch(stacks, elb)
      end

      it 'should detach the ASG from Blue stack from the ELB after successfully attaching the Green stack ASG' do
        allow(blue_cs).to receive(:get_desired_capacity).and_return(1)

        expect(green_cs).to receive(:attach_to_elb_and_wait).with(elb, 1).ordered
        expect(blue_cs).to receive(:detach_from_elb_and_wait).with(elb).ordered

        ac24.switch(stacks, elb)
      end
    end
  end


  context 'Canary deployment' do
    let(:stacks) { {:stack_to_create => green_cs, :stack_to_delete => blue_cs} }

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 1' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 1}) }
      it 'should add exactly 1 instances at a time' do
        allow(blue_cs).to receive(:detach_from_elb_and_wait)
        allow(blue_cs).to receive(:get_desired_capacity).and_return(5)

        expect(green_cs).to receive(:attach_to_elb_and_wait).with(elb, 1).exactly(5).times

        ac24.switch(stacks, elb)
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 10' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 10}) }
      it 'should add exactly 1 instances at a time' do
        allow(blue_cs).to receive(:detach_from_elb_and_wait)
        allow(blue_cs).to receive(:get_desired_capacity).and_return(5)

        expect(green_cs).to receive(:attach_to_elb_and_wait).with(elb, 1).exactly(5).times

        ac24.switch(stacks, elb)
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 50' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 50}) }
      it 'should add 3 instances the first time and 2 instances the second time' do
        allow(blue_cs).to receive(:detach_from_elb_and_wait)
        allow(blue_cs).to receive(:get_desired_capacity).and_return(5)

        expect(green_cs).to receive(:attach_to_elb_and_wait).with(elb, 3).exactly(1).times.ordered
        expect(green_cs).to receive(:attach_to_elb_and_wait).with(elb, 2).exactly(1).times.ordered

        ac24.switch(stacks, elb)
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 80' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 80}) }
      it 'should add 4 instances the first time and 1 instance the second time' do
        allow(blue_cs).to receive(:detach_from_elb_and_wait)
        allow(blue_cs).to receive(:get_desired_capacity).and_return(5)

        expect(green_cs).to receive(:attach_to_elb_and_wait).with(elb, 4).exactly(1).times.ordered
        expect(green_cs).to receive(:attach_to_elb_and_wait).with(elb, 1).exactly(1).times.ordered

        ac24.switch(stacks, elb)
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 100' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 100}) }
      it 'should add 5 instances the first time' do
        allow(blue_cs).to receive(:detach_from_elb_and_wait)
        allow(blue_cs).to receive(:get_desired_capacity).and_return(5)

        expect(green_cs).to receive(:attach_to_elb_and_wait).with(elb, 5).exactly(1).times

        ac24.switch(stacks, elb)
      end
    end

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
  end

  context 'After switch' do
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

  # Switch when only one stack is available

  #     it 'should always be 5 or more instances (overall) during deployment' do
  #       pending
  #     end

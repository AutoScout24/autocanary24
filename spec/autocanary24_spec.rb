require 'spec_helper'

describe AutoCanary24::Client do
  let(:ac24) { AutoCanary24::Client.new }
  let(:elb) { "ELB-123" }
  let(:blue_cs) { AutoCanary24::CanaryStack.new('mystack-B') }
  let(:green_cs) { AutoCanary24::CanaryStack.new('mystack-G') }
  let(:green_instances) { [ { instance_id: 'i-872a6e01'}, {instance_id: 'i-872a6e02'}, {instance_id: 'i-872a6e03'}, {instance_id: 'i-872a6e04'}, {instance_id: 'i-872a6e05'} ] }
  let(:blue_instances) { [ { instance_id: 'i-315b7e01'}, {instance_id: 'i-315b7e02'}, {instance_id: 'i-315b7e03'}, {instance_id: 'i-457b7e04'}, {instance_id: 'i-457b7e05'} ] }
  let(:stack_name) { 'mystack' }
  let(:template) { 'template' }
  let(:parameters) { { param: "value" }}
  let(:tags) { [{ tag: "value" }] }
  let(:deployment_check) { lambda { |stacks, elb, instances_to_create| true } }

  before do
    allow(blue_cs).to receive(:get_instance_ids).and_return(blue_instances.take(5))
    allow(green_cs).to receive(:get_instance_ids).and_return(green_instances.take(5))
    allow(ac24).to receive(:get_elb).with(stack_name).and_return(elb)
  end

  context 'Before switch' do
    before do
      allow(ac24).to receive(:get_canary_stack).with('mystack-B').and_return(blue_cs)
      allow(ac24).to receive(:get_canary_stack).with('mystack-G').and_return(green_cs)
      allow(ac24).to receive(:switch)
      allow(ac24).to receive(:after_switch)
    end

    describe 'when blue is currently active' do

      it 'should activate the green stack' do
        allow(blue_cs).to receive(:is_attached_to).with(elb).and_return(true)
        allow(green_cs).to receive(:is_attached_to).with(elb).and_return(false)

        expected_stacks = {stack_to_create: green_cs, stack_to_delete: blue_cs}
        expect(ac24).to receive(:before_switch).with(expected_stacks, template, parameters, stack_name, tags)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when green is currently active' do
      it 'should activate the blue stack' do
        allow(blue_cs).to receive(:is_attached_to).with(elb).and_return(false)
        allow(green_cs).to receive(:is_attached_to).with(elb).and_return(true)

        expected_stacks = {stack_to_create: blue_cs, stack_to_delete: green_cs}
        expect(ac24).to receive(:before_switch).with(expected_stacks, template, parameters, stack_name, tags)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when no stack is active' do
      it 'should activate the blue stack' do
        allow(blue_cs).to receive(:is_attached_to).with(elb).and_return(false)
        allow(green_cs).to receive(:is_attached_to).with(elb).and_return(false)

        expected_stacks = {stack_to_create: blue_cs, stack_to_delete: nil}
        expect(ac24).to receive(:before_switch).with(expected_stacks, template, parameters, stack_name, tags)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when desired count of active stack is 5' do

      it 'should create the new stack' do
        allow(green_cs).to receive(:is_attached_to).with(elb).and_return(true)
        allow(blue_cs).to receive(:is_attached_to).with(elb).and_return(false)
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(blue_cs).to receive(:set_desired_capacity_and_wait)
        allow(blue_cs).to receive(:suspend_asg_processes)
        allow(green_cs).to receive(:suspend_asg_processes)

        expect(ac24).to receive(:create_stack).with('mystack-B', template, parameters, stack_name, tags)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end

      it 'should be 5 instances after creation' do
        allow(green_cs).to receive(:is_attached_to).with(elb).and_return(true)
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(blue_cs).to receive(:suspend_asg_processes)
        allow(green_cs).to receive(:suspend_asg_processes)
        allow(ac24).to receive(:create_stack)

        expect(blue_cs).to receive(:set_desired_capacity_and_wait).with(5)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end

      it 'should suspend processes from both ASG' do
        allow(green_cs).to receive(:is_attached_to).with(elb).and_return(true)
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(blue_cs).to receive(:set_desired_capacity_and_wait)
        allow(ac24).to receive(:create_stack)

        expect(blue_cs).to receive(:suspend_asg_processes)
        expect(green_cs).to receive(:suspend_asg_processes)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end
  end

  context 'Switch (Blue/Green)' do
    before do
      stacks = {stack_to_create: green_cs, stack_to_delete: blue_cs}
      allow(ac24).to receive(:get_stacks_to_create_and_to_delete_for).and_return(stacks)

      allow(ac24).to receive(:before_switch)
      allow(ac24).to receive(:after_switch)
    end

    describe 'when switching from Blue to Green stack' do

      it 'should attach all instances from Green stack to the ELB' do
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(green_cs).to receive(:attach_asg_to_elb_and_wait).with(elb)
        allow(blue_cs).to receive(:detach_asg_from_elb_and_wait).with(elb)

        expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, green_instances.take(5))

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end

      it 'should detach all instances from Blue stack from the ELB after successfully attaching the Green stack ASG' do
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(green_cs).to receive(:attach_asg_to_elb_and_wait).with(elb)

        expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, green_instances.take(5)).ordered
        expect(blue_cs).to receive(:detach_asg_from_elb_and_wait).with(elb).ordered

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end
  end

  context 'Canary deployment' do
    before do
      stacks = {stack_to_create: green_cs, stack_to_delete: blue_cs}
      allow(ac24).to receive(:get_stacks_to_create_and_to_delete_for).and_return(stacks)

      allow(ac24).to receive(:before_switch)
      allow(ac24).to receive(:after_switch)
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 1' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 1}) }

      it 'should add exactly 1 instances at a time' do
        allow(ac24).to receive(:before_switch)
        allow(ac24).to receive(:after_switch)

        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(green_cs).to receive(:attach_asg_to_elb_and_wait)
        allow(blue_cs).to receive(:detach_asg_from_elb_and_wait)

        green_instances.take(5).each {|i|
          expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, [i])
        }

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 10' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 10}) }
      it 'should add exactly 1 instances at a time' do
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(green_cs).to receive(:attach_asg_to_elb_and_wait)
        allow(blue_cs).to receive(:detach_asg_from_elb_and_wait)

        green_instances.take(5).each {|i|
          expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, [i])
        }

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 50' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 50}) }
      it 'should add 3 instances the first time and 2 instances the second time' do
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(green_cs).to receive(:attach_asg_to_elb_and_wait)
        allow(blue_cs).to receive(:detach_asg_from_elb_and_wait)

        expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, green_instances[0,3]).ordered
        expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, green_instances[3,2]).ordered

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 80' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 80}) }
      it 'should add 4 instances the first time and 1 instance the second time' do
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(green_cs).to receive(:attach_asg_to_elb_and_wait)
        allow(blue_cs).to receive(:detach_asg_from_elb_and_wait)

        expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, green_instances[0,4]).ordered
        expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, green_instances[4,1]).ordered

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 100' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 100}) }
      it 'should add 5 instances the first time' do
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(green_cs).to receive(:attach_asg_to_elb_and_wait)
        allow(blue_cs).to receive(:detach_asg_from_elb_and_wait)

        expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, green_instances.take(5))

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when keep_instances_balanced is true' do
      let(:ac24) { AutoCanary24::Client.new({scaling_instance_percent: 50, keep_instances_balanced: true }) }

      it 'should remove x instance(s) from current stack after x new instance(s) were added to the new stack' do
        allow(green_cs).to receive(:get_desired_capacity).and_return(5)
        allow(green_cs).to receive(:attach_asg_to_elb_and_wait)
        allow(blue_cs).to receive(:detach_asg_from_elb_and_wait)

        expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, green_instances[0,3]).ordered
        expect(blue_cs).to receive(:detach_instances_from_elb).with(elb, blue_instances[0, 3]).ordered
        expect(green_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, green_instances[3,2]).ordered
        expect(blue_cs).to receive(:detach_instances_from_elb).with(elb, blue_instances[3, 2]).ordered

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end
  end

  context 'After switch' do
    before do
      stacks = {stack_to_create: green_cs, stack_to_delete: blue_cs}
      allow(ac24).to receive(:get_stacks_to_create_and_to_delete_for).and_return(stacks)

      allow(ac24).to receive(:before_switch)
      allow(ac24).to receive(:switch)
    end

    describe 'when configuration of keep_inactive_stack is TRUE' do
      it 'should keep the inactive stack' do
        allow(blue_cs).to receive(:resume_asg_processes)
        allow(green_cs).to receive(:resume_asg_processes)

        expect(ac24).to receive(:delete_stack).with('mystack').exactly(0).times

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when configuration of keep_inactive_stack is FALSE' do
      it 'should delete the inactive stack' do
        allow(blue_cs).to receive(:resume_asg_processes)
        allow(green_cs).to receive(:resume_asg_processes)

        expect(ac24).to receive(:delete_stack).with(blue_cs)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end
  end

  context 'Rollback' do
    before do
      stacks = {stack_to_create: green_cs, stack_to_delete: blue_cs}
      allow(ac24).to receive(:get_stacks_to_create_and_to_delete_for).and_return(stacks)

      allow(ac24).to receive(:before_switch)

      allow(green_cs).to receive(:get_desired_capacity).and_return(5)
    end

    describe 'when switching from Blue to Green stack and a user-defined deployment check fails' do
      let(:deployment_check) { lambda { |stacks, elb, instances_to_create| false } }

      it 'should trigger a rollback' do
        allow(ac24).to receive(:after_switch)
        expect(ac24).to receive(:rollback)
        expect(green_cs).not_to receive(:attach_asg_to_elb)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when switching from Blue to Green stack and new instances dont get healthy at the ELB' do
      it 'should trigger a rollback' do
        allow(ac24).to receive(:after_switch)
        allow(green_cs).to receive(:attach_instances_to_elb_and_wait).and_raise("timeout")

        expect(ac24).to receive(:rollback)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end

    describe 'when a rollback was triggered' do
      let(:deployment_check) { lambda { |stacks, elb, instances_to_create| false } }

      it 'should remove already added instances from Green stack from ELB' do
        allow(ac24).to receive(:after_switch)
        expect(green_cs).to receive(:detach_instances_from_elb_and_wait).with(elb, green_instances)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end

      it 'should add already removed instances from Blue stack to the ELB' do
        allow(ac24).to receive(:after_switch)
        allow(green_cs).to receive(:detach_instances_from_elb_and_wait).with(elb, green_instances)
        expect(blue_cs).to receive(:attach_instances_to_elb_and_wait).with(elb, blue_instances)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end

      it 'should not terminate the instances of the Green stack' do
        allow(blue_cs).to receive(:resume_asg_processes)
        allow(green_cs).to receive(:resume_asg_processes)
        expect(ac24).not_to receive(:delete_stack)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end

      it 'should resume the ASG processes' do
        expect(blue_cs).to receive(:resume_asg_processes)
        expect(green_cs).to receive(:resume_asg_processes)

        ac24.deploy_stack(stack_name, template, parameters, tags, deployment_check)
      end
    end
  end
end

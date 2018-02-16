require 'spec_helper'

describe AutoCanary24::CanaryStack do

    elb_name = "ELB-123"

    ElbStub = Struct.new(:state_name, :name) do
      def state
        state_name
      end

      def load_balancer_name
        name
      end
    end

    describe 'when elb is in "Removed" state' do
      it 'should not be attached to elb' do
        elb = ElbStub.new("Removed", elb_name)
        autoscaling_group_stub = Class.new

        stack = AutoCanary24::CanaryStack.new('mystack-B', 300)

        allow(stack).to receive(:get_autoscaling_group).and_return(autoscaling_group_stub)
        allow(stack).to receive(:get_attached_loadbalancers).and_return([elb])

        expect(stack.is_attached_to(elb_name)).to equal(false)
      end
    end

    describe 'when elb is in "Removing" state' do
      it 'should not be attached to elb' do
        elb = ElbStub.new("Removing", elb_name)
        autoscaling_group_stub = Class.new

        stack = AutoCanary24::CanaryStack.new('mystack-B', 300)

        allow(stack).to receive(:get_autoscaling_group).and_return(autoscaling_group_stub)
        allow(stack).to receive(:get_attached_loadbalancers).and_return([elb])

        expect(stack.is_attached_to(elb_name)).to equal(false)
      end
    end

    context 'isStackCreated?' do
      describe 'when a stack is not created' do
        it 'should return false' do
          stack = AutoCanary24::CanaryStack.new('mystack-B', 300)

          expect(stack.is_stack_created?).to equal(false)
        end
      end

      describe 'when a stack is created' do
        it 'should return true' do
          stack = AutoCanary24::CanaryStack.new('mystack-B', 300)
          allow(stack).to receive(:get_instance_ids)

          expect(stack.is_stack_created?).to equal(true)
        end
      end
    end
end
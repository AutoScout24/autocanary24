require 'spec_helper'

describe AutoCanary24::Client do
  let(:client) { AutoCanary24::Client.new }

  context 'Deployment' do
    describe 'when blue is currently active' do
      it 'should activate the green stack' do
      end
    end

    describe 'when green is currently active' do
      it 'should activate the blue stack' do
      end
    end

    describe 'when keep_instances_balanced is true' do
      it 'should remove x instance(s) from current stack after x new instance(s) were added to the new stack' do
      end
    end

    describe 'when keep_instances_balanced is false' do
      it 'should not remove instances from current stack after adding new instances to the new stack' do
      end
      it 'should remove all instances from current stack after adding all instances of the new stack' do
      end
    end

  end

  context 'After deployment' do
    describe 'when the deployment is done' do
      it 'should not send traffic to the inactive stack' do
      end
    end

    describe 'when configuration of inactive_stack_state is TERMINATE' do
      it 'should terminate the inactive stack' do
      end
    end
    describe 'when configuration of inactive_stack_state is STANDBY' do
      it 'should set the inactive stack to standby' do
      end
    end
    describe 'when configuration of inactive_stack_state is INSERVICE' do
      it 'should keep the inactive stack' do
      end
    end
  end

  context 'Advanced deployment' do

    describe 'when desired count of active stack is 5' do
      it 'should be 5 instances after the deployment' do
      end
      it 'should always be 5 or more instances (overall) during deployment' do
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 10' do
      it 'should add exactly 1 instances at a time' do
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 50' do
      it 'should add 3 instances the first time' do
      end
      it 'should add 2 instances the second time' do
      end
    end

    describe 'when desired count of active stack is 5 and scaling_instance_percent is 80' do
      it 'should add 4 instances the first time' do
      end
      it 'should add 1 instances the second time' do
      end
    end

    describe 'when new instances are added and scaling_wait_interval is set to 5 sec' do
      it 'should wait 5sec after the instances were added' do
      end
    end
  end

  context 'Hooks' do
    # TODO Support hooks/callbacks to cancel/rollback the deployment (canary release)
  end

end

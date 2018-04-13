require 'spec_helper'

describe AutoCanary24::CanaryStack do
  elb_name = "ELB-123"
  
  before do
    @instances =
      [{instance_id: "i-123",}]
    @instance_responses = {
      instance_states: [
        {
          description: "N/A", 
          instance_id: "i-207d9717", 
          reason_code: "N/A", 
          state: "NotInService", 
        }, 
        {
          description: "N/A", 
          instance_id: "i-afefb49b", 
          reason_code: "N/A", 
          state: "NotInService", 
        }, 
      ], 
    }
    @elb_client = Aws::ElasticLoadBalancing::Client.new(stub_responses: true)
    allow(Aws::ElasticLoadBalancing::Client).to receive(:new).and_return(@elb_client)
  end
  
  describe 'when AWS API returns Aws::CloudFormation::Errors::Throttling "Rate Exceeded" exception' do
    it 'should back off and retry' do
      @elb_client.stub_responses(:describe_instance_health,
        Aws::CloudFormation::Errors::Throttling.new("First parm", "Rate Exceeded"),
        Aws::CloudFormation::Errors::Throttling.new("First parm", "Rate Exceeded"),
        @instance_responses
      )

      stack = AutoCanary24::CanaryStack.new('mystack-B', 300)

      expect(stack.send(:wait_for_instances_detached_from_elb, @instances, elb_name)).to eq nil
    end

    it 'should raise exception after 5 throttling errors' do
      @elb_client.stub_responses(:describe_instance_health,
        Aws::CloudFormation::Errors::Throttling.new("First parm", "Rate Exceeded"),
        # Aws::CloudFormation::Errors::Throttling.new("First parm", "Rate Exceeded"),
        # Aws::CloudFormation::Errors::Throttling.new("First parm", "Rate Exceeded"),
        # Aws::CloudFormation::Errors::Throttling.new("First parm", "Rate Exceeded"),
        # Aws::CloudFormation::Errors::Throttling.new("First parm", "Rate Exceeded"),
      )

      stack = AutoCanary24::CanaryStack.new('mystack-B', 300)
    
      expect(stack.send(:wait_for_instances_detached_from_elb, @instances, elb_name)).to raise_exception(Aws::CloudFormation::Errors::Throttling)
    end
  end
end
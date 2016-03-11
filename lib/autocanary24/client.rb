require 'aws-sdk-core'
require 'autostacker24'
require 'base64'

module AutoCanary24
  class StackState
    INSERVICE
    STANDBY
    TERMINATE
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
      # initialize with some defaults
      @inactive_stack_state = StackState.TERMINATE
      @inactive_stack_state_after = nil
      @keep_instances_balanced = false
      @scaling_instance_percent = 100
      @scaling_wait_interval = nil
    end

  end

  class Client
    def initialize(**params)
      @configuration = params[:configuration].nil ? Configuration:new : params[:configuration]
    end

    def deploy_stack(stack_name, template, parameters, parent_stack_name = nil, tags = nil)
      begin

        stack_to_activate = "#{stack_name}_B"

        Stacker.create_or_update_stack(stack_to_activate, template, parameters, parent_stack_name, tags)

        # client.create_repository(repository_name: repo)
      rescue Exception => e
        puts e
      end
    end
  end
end

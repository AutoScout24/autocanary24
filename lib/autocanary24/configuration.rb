module AutoCanary24
  class Configuration
    # Defines what should happen with the inactive stack
    attr_accessor :keep_inactive_stack
    # If true a instance from current stack gets removed whenever a new instance from the new stack is added.
    attr_accessor :keep_instances_balanced
    # Percent of instances which are added at once (depends on the actual number of instances, read from desired)
    attr_accessor :scaling_instance_percent

    def initialize(**params)

      @keep_inactive_stack = false
      unless params[:keep_inactive_stack].nil?
        raise "ERR: inactive_stack_state should be a boolean" unless [true, false].include? params[:keep_inactive_stack]
        @keep_inactive_stack = params[:keep_inactive_stack]
      end

      @keep_instances_balanced = false
      unless params[:keep_instances_balanced].nil?
        raise 'ERR: keep_instances_balanced needs to a boolean' unless params[:keep_instances_balanced].is_a?(Bool)
        @keep_instances_balanced = params[:keep_instances_balanced]
      end

      @scaling_instance_percent = 100
      unless params[:scaling_instance_percent].nil?
        raise 'ERR: scaling_instance_percent needs to be a number between 1 and 100' unless params[:scaling_instance_percent].is_a?(Integer) && (1..100).include?(params[:scaling_instance_percent])
        @scaling_instance_percent = params[:scaling_instance_percent]
      end

    end
  end
end

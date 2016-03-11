# AutoCanary24

Ruby utility to do [blue/green](http://martinfowler.com/bliki/BlueGreenDeployment.html) and [canary](http://martinfowler.com/bliki/CanaryRelease.html) deployments with AWS CloudFormation stacks.

This library use the [Swap AutoScaling Groups](http://www.slideshare.net/AmazonWebServices/dvo401-deep-dive-into-bluegreen-deployments-on-aws/32) and expects two stacks. One "base" stack which includes at least the `ELB` and another which includes the `AutoScaling Group`.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'autocanary24'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install autocanary24


## Usage

Initialize the client, e.g. in your `Rakefile`:

```ruby
ac = AutoCanary24::Client.new(configuration: {})
ac.deploy_stack(stack_name, template, parameters, parent_stack_name = nil, tags = nil)
```

The available configuration:
- `inactive_stack_state`: Defines what should happen with the inactive stack
- `inactive_stack_state_after`: Wait time until the inactive_stack_state is applied to the inactive stack (will be ignored when inactive_stack_state is inService)
- `keep_instances_balanced`: If true a instance from current stack gets removed whenever a new instance from the new stack is added.
- `scaling_instance_percent`: Percent of instances which are added at once (depends on the actual number of instances, read from desired)
- `scaling_wait_interval`: Wait time before the next instances are added


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/autoscout24/autocanary24.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

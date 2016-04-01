# AutoCanary24

[![Build Status](https://travis-ci.org/AutoScout24/autocanary24.svg)](https://travis-ci.org/AutoScout24/autocanary24)

AutoCanary24 is a ruby utility to do [blue/green](http://martinfowler.com/bliki/BlueGreenDeployment.html) and [canary](http://martinfowler.com/bliki/CanaryRelease.html) deployments with AWS CloudFormation stacks.

This library use the [Swap AutoScaling Groups](http://www.slideshare.net/AmazonWebServices/dvo401-deep-dive-into-bluegreen-deployments-on-aws/32) approach and expects two stacks. A "base" stack which includes at least the `ELB` and another which includes the `AutoScaling Group`.


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

Prerequisite: Deploy the base stack before

Initialize the client, e.g. in your `Rakefile` and deploy your stack:

```ruby
# Configure the AutoCanary24 Client
ac = AutoCanary24::Client.new({
  keep_inactive_stack: false,
  keep_instances_balanced: false,
  scaling_instance_percent: 50
})
```

The available configuration:
- `keep_inactive_stack`: If `true` the inactive stack gets not deleted.
  Default is `false`
- `keep_instances_balanced`: If `true` a instance from current stack gets removed whenever a new instance from the new stack is added. If `false` first all new instances are created and afterwards the old instances gets removed.
  Default is `false`
- `scaling_instance_percent`: Percent of instances which are added at once (depends on the actual number of instances, read from desired).
  Default is `100`
- `wait_timeout`: Timeout in seconds to wait for checking AWS operations are done before do a rollback.
  Default is `300`

```ruby
# Execute the deployment
ac.deploy_stack(parent_stack_name, template, parameters, tags, deployment_check)
```

The available parameters:
- `parent_stack_name`: the name of the 'base' stack. In addition `AutoStacker24` will read the output parameters of an existing stack and merge them to the given parameters.
- `template`: is either the template json data itself or the name of a file containing the template body
- `parameters`: specify the input parameter as a simple ruby hash. It gets converted to the
  cumbersome AWS format automatically.
  The template body will be validated and optionally preprocessed.
- `tags`: Optional. Key-value pairs to associate with this stack.
- `deployment_check`: Optional. A `lambda` which is executed whenever new instances are added to the ELB. If `true` AutoCanary continues, if `false` it will rollback to the current stack.

> For more information about stacked CloudFormation stacks visit [AutoStacker24](https://github.com/autoscout24/autostacker24).




### Examples
Have a look into the [examples subfolder](https://github.com/autoscout24/autocanary24/blob/master/examples/)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/autoscout24/autocanary24.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

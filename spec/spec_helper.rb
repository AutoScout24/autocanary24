$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'autocanary24'
require 'aws-sdk-core'

RSpec.configure do |config|
  Aws.config.update(stub_responses: true)

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'autocanary24/version'

Gem::Specification.new do |spec|
  spec.name          = "autocanary24"
  spec.version       = AutoCanary24::VERSION
  spec.authors       = ["Philipp Garbe"]
  spec.email         = ["pgarbe@autoscout24.com"]

  spec.summary       = %q{A very narrow interface to AWS ECR}
  spec.description   = %q{autocanary24 provides a small convenient module for blue/green deployments with CloudFormation.}
  spec.homepage      = "https://github.com/autoscout24/autocanary24"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'autocanary24/version'

Gem::Specification.new do |spec|
  spec.name          = "autocanary24"
  spec.version       = AutoCanary24::VERSION
  spec.authors       = ["Philipp Garbe"]
  spec.email         = ["pgarbe@autoscout24.com"]

  spec.summary       = %q{Library for blue/green and canary deployments with CloudFormation.}
  spec.description   = %q{autocanary24 provides a small convenient module for blue/green and canary deployments with CloudFormation.}
  spec.homepage      = "https://github.com/autoscout24/autocanary24"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'autostacker24', '~> 2.0.2'
  spec.add_dependency 'aws-sdk-core', '~> 2'

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end

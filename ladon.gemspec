# -*- encoding: utf-8 -*-
require File.expand_path('../lib/ladon/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'ladon'
  s.version = Ladon::VERSION.dup
  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6") if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")
  s.authors = ['Brian Moseley']
  s.description = 'A HTTP service client framework based on Typhoeus'
  s.email = ['bcm@copious.com']
  s.homepage = 'http://github.com/utahstreetlabs/ladon'
  s.extra_rdoc_files = ['README.md']
  s.rdoc_options = ['--charset=UTF-8']
  s.summary = "A framework for building fast HTTP service clients based on Typhoeus"
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.files = `git ls-files -- lib/*`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.add_development_dependency('rake')
  s.add_development_dependency('rspec', '>= 2.13.0')
  s.add_development_dependency('mocha')
  s.add_development_dependency('gemfury')
  s.add_runtime_dependency('activemodel', ['>= 3.1.0'])
  s.add_runtime_dependency('typhoeus', ["~> 0.2.4.2.copious"])
  s.add_runtime_dependency('yajl-ruby')
  s.add_runtime_dependency('airbrake')
  s.add_runtime_dependency('resque')
  s.add_runtime_dependency('resque-unique-job')
  s.add_runtime_dependency('resque-retry')
  s.add_runtime_dependency('log_weasel', '~> 0.1.0')
end

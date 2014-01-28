require 'rubygems'
require 'bundler'

Bundler.setup

require 'rspec'
require 'mocha_standalone'
require 'ladon'

Ladon.hydra = Typhoeus::Hydra.new
Ladon.logger = Logger.new(File.join("log", "test.log"))

RSpec.configure do |config|
  config.mock_with :mocha
end

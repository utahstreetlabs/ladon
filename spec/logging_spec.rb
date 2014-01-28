require 'spec_helper'
require 'ladon/logging'

describe Ladon::Logging do
  class TestThing
    include Ladon::Logging
  end

  it "lets consumers get and set the logger" do
    logger = Logger.new('/dev/null')
    Ladon.logger = logger
    Ladon.logger.should == logger
  end

  it "has an instance-level logger" do
    TestThing.logger.should == Ladon.logger
  end

  it "has a class-level logger" do
    TestThing.new.logger.should == Ladon.logger
  end
end

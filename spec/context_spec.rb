require 'spec_helper'
require 'ladon/context'

describe Ladon::Context do
  class TestContext
    include Ladon::Context
  end

  let(:value) { {made_of: :bacon} }
  let(:stored_value) { {made_of: :bacon} }

  it "exposes the ladon context as a class method" do
    TestContext.ladon_context[:hams] = value
    TestContext.ladon_context[:hams].should == stored_value
  end

  it "exposes the ladon context as an instance method" do
    TestContext.new.ladon_context[:hams] = value
    TestContext.new.ladon_context[:hams].should == stored_value
  end

  describe '#clear_ladon_context!' do
    it 'clears the ladon context' do
      TestContext.ladon_context[:hams] = value
      TestContext.clear_ladon_context!
      TestContext.ladon_context.should == {}
    end
  end
end

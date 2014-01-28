require 'spec_helper'
require 'ladon/error_handling'

describe Ladon::ErrorHandling do
  class TestThing
    include Ladon::ErrorHandling
  end

  let(:error_class) { 'error-class' }
  let(:error_message) { 'error-message' }
  let(:parameters) { { foo: :bar} }

  it "logs an error and notifies airbrake when handling an error" do
    TestThing.logger.expects(:error)
    Airbrake.expects(:notify).
      with(is_a(Exception), has_entries(error_class: error_class, parameters: parameters))
    TestThing.handle_error(error_class, error_message, parameters)
  end

  it "logs an warning but does not notify airbrake when handling an warning" do
    TestThing.logger.expects(:warn)
    Airbrake.expects(:notify).never
    TestThing.handle_warning(error_class, error_message)
  end

  describe '#with_error_handling' do
    let(:exception) { Exception.new('Oh no!') }
    it "handles the error" do
      TestThing.expects(:handle_error).with(error_message, exception, parameters)
      TestThing.with_error_handling(error_message, parameters) do
        raise exception
      end
    end

    it 'retries the block before bailing out' do
      retry_count = 3
      p = parameters.merge(retry_count: retry_count)
      count = 0
      TestThing.with_error_handling(error_message, p) do
        count += 1
        raise exception unless count > retry_count
      end
      count.should == retry_count+1
    end

    it 'calls an additional error handler lambda if one is provided' do
      called = false
      p = parameters.merge(additionally: lambda { called = true })
      TestThing.expects(:handle_error).with(error_message, exception, parameters)
      TestThing.with_error_handling(error_message, p) do
        raise exception
      end
      called.should be_true
    end
  end
end

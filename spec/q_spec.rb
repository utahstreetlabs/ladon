require 'spec_helper'
require 'ladon/q'
require 'ladon/job'

describe Ladon::Q do
  it "queues with Resque by default" do
    Resque.expects(:enqueue)
    Ladon::Q.enqueue(TestJob)
  end

  it "handles the error if a job can't be enqueued" do
    e = Exception.new("Oh no")
    Ladon.q.expects(:enqueue).raises(e)
    Ladon::Q.expects(:handle_error).with(is_a(String), e, is_a(Hash))
    Ladon::Q.enqueue(TestJob)
  end
end

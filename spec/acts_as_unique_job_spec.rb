
require 'spec_helper'

describe Ladon::Job do
  class UniqueTestJob < Ladon::Job
    acts_as_unique_job

    @queue = :foobar
  end

  it "should not extend Resque::Plugins::UniqueJob by default" do
    Ladon::Job.kind_of?(Resque::Plugins::UniqueJob).should be_false
  end

  it "should extend Resque::Plugins::UniqueJob" do
    UniqueTestJob.kind_of?(Resque::Plugins::UniqueJob).should be_true
  end

  context "#enqueue" do
    let!(:worker) { Resque::Worker.new(:foobar) }

    before do
#      worker.work(0)
    end

    after do
#      Resque.redis.keys.each do |k|
#        Resque.redis.del(k) if k =~ /^plugin:unique_job/
#      end
#      Resque.redis.del "queue:foobar"
    end

    context "when injecting a job" do
      it "succeeds for the first job" do
        pending "unit tests should not depend on redis being available"
        UniqueTestJob.enqueue(UniqueTestJob)
        Resque.size(:foobar).should == 1
      end

      it "fails when injecting a second identical job" do
        pending "unit tests should not depend on redis being available"
        UniqueTestJob.enqueue(UniqueTestJob)
        Resque.size(:foobar).should == 1
        UniqueTestJob.enqueue(UniqueTestJob)
        Resque.size(:foobar).should == 1
      end
    end
  end
end

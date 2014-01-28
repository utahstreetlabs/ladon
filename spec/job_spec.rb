require 'spec_helper'

describe Ladon::Job do
  class TestJob < Ladon::Job
    def self.work()
      'dabu'
    end
  end


  describe "#perform" do
    it 'calls work with the arguments passed to perform with no ladon context' do
      TestJob.expects(:work).with(:a)
      TestJob.perform(:a)
    end

    it 'calls work with the arguments passed to perform after stripping ladon context' do
      TestJob.expects(:work).with(:a)
      TestJob.perform(:a, ladon_context: {hi: :there})
    end

    it 'calls work with the arguments passed to perform after stripping ladon context' do
      TestJob.expects(:work).with(:a, {hams: :bacon})
      TestJob.perform(:a, hams: :bacon, ladon_context: {hi: :there})
    end

    it 'recursively symbolizes keys for all args' do
      TestJob.expects(:work).with(:a, {foo: :bar, fuz: {baz: :bats}}, hams: :bacon, beef: {steaks: :porterhouses}).times(3)
      TestJob.perform(:a, {foo: :bar, fuz: {baz: :bats}}, hams: :bacon, beef: {steaks: :porterhouses})
      TestJob.perform(:a, {'foo' => :bar, 'fuz' => {baz: :bats}}, 'hams' => :bacon, 'beef' =>  {steaks: :porterhouses})
      TestJob.perform(:a, {'foo' => :bar, 'fuz' => {'baz' => :bats}}, 'hams' => :bacon, 'beef' => {'steaks' => :porterhouses})
    end

    it 'sets ladon context inside the work method and clears it afterward' do
      class TestJob < Ladon::Job
        def self.work(*args)
          ladon_context.clone
        end
      end
      TestJob.perform(:a, hams: :bacon, ladon_context: {hi: :there}).should == {hi: :there}
      TestJob.ladon_context.should == {}
    end
  end

  describe 'ladon context transferral' do
    let(:ladon_foo_context) { {bar: :baz} }
    before { TestJob.ladon_context[:foo] = ladon_foo_context }
    [:enqueue].each do |m|
      it 'packs ladon context into the args' do
        Resque.expects(m).with(TestJob, {ladon_context: {foo: ladon_foo_context}})
        TestJob.send(m)
      end

      it 'skips packing ladon context if include_ladon_context? false' do
        Resque.expects(m).with(TestJob)
        TestJob.expects(:include_ladon_context?).returns(false)
        TestJob.send(m)
      end

      it 'still passes along options if include_ladon_context? false' do
        Resque.expects(m).with(TestJob, hi: :there)
        TestJob.expects(:include_ladon_context?).returns(false)
        TestJob.send(m, hi: :there)
      end
    end

    [:enqueue_in, :enqueue_at].each do |m|
      it 'packs ladon context into the args' do
        Resque.expects(m).with(4, TestJob, {ladon_context: {foo: ladon_foo_context}})
        TestJob.send(m, 4)
      end

      it 'skips packing ladon context if include_ladon_context? false' do
        Resque.expects(m).with(4, TestJob)
        TestJob.expects(:include_ladon_context?).returns(false)
        TestJob.send(m, 4)
      end

      it 'still passes along options if include_ladon_context? false' do
        Resque.expects(m).with(4, TestJob, hi: :there)
        TestJob.expects(:include_ladon_context?).returns(false)
        TestJob.send(m, 4, hi: :there)
      end
    end
  end
end

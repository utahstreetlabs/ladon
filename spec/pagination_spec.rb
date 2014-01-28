require 'spec_helper'

describe Ladon::PaginatableArray do
  let(:data) { [1,2,3,4,5] }
  let(:params) { {total: 20, offset: 2, limit: 5} }
  let(:original) { Ladon::PaginatableArray.new(data, params) }

  context "#map" do
    subject { original.map {|v| v+1} }
    its([2]) { should == original[2] + 1 }
    its(:total_count) { should == params[:total] }
    its(:offset_value) { should == params[:offset] }
    its(:limit_value) { should == params[:limit] }
  end
end

describe Ladon::PaginatedCollection do
  it "should encapsulate a series of paged collection requests" do
    pages = [
      Ladon::PaginatableArray.new([1, 2, 3], offset: 0, limit: 3, total: 9),
      Ladon::PaginatableArray.new([4, 5, 6], offset: 3, limit: 3, total: 9),
      Ladon::PaginatableArray.new([7, 8, 9], offset: 6, limit: 3, total: 9),
    ]
    Ladon::PaginatedCollection.new { |paging_opts| pages[paging_opts[:page] - 1] }.
      to_a.should == [1, 2, 3, 4, 5, 6, 7, 8, 9]
  end
end

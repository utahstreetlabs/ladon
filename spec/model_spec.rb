require 'spec_helper'

class TestModel < Ladon::Model
  attr_accessor :foo, :bar, :baz
  attr_datetime :expiry
  attr_symbol :foo
end

describe Ladon::Model do
  before { Time.zone = 'UTC' }

  it "sets id" do
    id = 'deadbeef'
    model = TestModel.new(_id: id)
    model.id.should == id
  end

  it "casts created_at to datetime" do
    dt = Time.zone.now.to_s
    model = TestModel.new(created_at: dt)
    model.created_at.to_s.should == dt
  end

  it "casts updated_at to datetime" do
    dt = Time.zone.now.to_s
    model = TestModel.new(updated_at: dt)
    model.updated_at.to_s.should == dt
  end

  it "casts expiry string to datetime" do
    e = Time.zone.now.to_s
    model = TestModel.new(expiry: e)
    model.expiry.to_s.should == e
  end

  it "casts expiry integer to datetime" do
    e = Time.zone.now.to_datetime.to_i
    model = TestModel.new(expiry: e)
    model.expiry.to_i.should == e
  end

  it "leaves expiry as datetime during assignment" do
    e = Time.zone.now.to_datetime
    model = TestModel.new(expiry: e)
    model.expiry.should == e
  end

  it "casts foo to symbol" do
    foo = 'hi'
    model = TestModel.new(foo: foo)
    model.foo.should == foo.to_sym
  end

  it "is persisted when _id is provided" do
    model = TestModel.new(_id: 'deadbeef')
    model.should be_persisted
  end

  it "is not persisted when _id is not provided" do
    model = TestModel.new
    model.should_not be_persisted
  end

  it "returns a hash of attributes" do
    attrs = {bar: 'bar', baz: 'baz'}
    model = TestModel.new(attrs)
    model.attributes.should include({'bar' => 'bar', 'baz' => 'baz'})
  end

  it "returns a hash of known attributes" do
    attrs = {bar: 'bar', baz: 'baz', badattribute: 'true'}
    model = TestModel.new(attrs)
    model.attributes.should include({'bar' => 'bar', 'baz' => 'baz'})
  end

  it "sets the dirty bit when updating an attribute" do
    attrs = {quux: 'quux'}
    model = TestModel.new(attrs)
    model.expects(:quux_will_change!)
    model.quux = 'shuux'
  end

  it "creates an tracked attribute" do
    model = TestModel.new({})
    model.changed?.should be_false
    model.frotz = 'lamp'
    model.changed?.should be_true
    model.frotz.should == 'lamp'
  end

  it "clears the dirty bit on save" do
    attrs = {quux: 'quux'}
    model = TestModel.new(attrs)
    model.quux = 'shuux'
    model.changed?.should be_true
    model.save
    model.changed?.should be_false
  end
end

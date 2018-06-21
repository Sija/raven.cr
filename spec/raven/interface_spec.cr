require "../spec_helper"

class Raven::Interface::Test < Raven::Interface
  property some_attr : String?
end

describe Raven::Interface do
  it "should register an interface when a new class is defined" do
    Raven::Interface.registered[:test].should eq(Raven::Interface::Test)
  end

  it "can be initialized with some attributes" do
    interface = Raven::Interface::Test.new(some_attr: "test")
    interface.some_attr.should eq("test")
  end

  it "can initialize with a block" do
    interface = Raven::Interface::Test.new { |iface| iface.some_attr = "test" }
    interface.some_attr.should eq("test")
  end

  it "serializes to a Hash" do
    interface = Raven::Interface::Test.new(some_attr: "test")
    interface.to_hash.should eq({:some_attr => "test"})
  end
end

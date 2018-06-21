require "../../spec_helper"

describe Raven::Interface::Message do
  it "supports invalid format string message when params is not defined" do
    interface = Raven::Interface::Message.new(params: nil, message: "test '%'")
    interface.unformatted_message.should eq("test '%'")
  end

  it "supports invalid format string message when params is empty" do
    interface = Raven::Interface::Message.new(message: "test '%'")
    interface.unformatted_message.should eq("test '%'")
  end
end

require "../spec_helper"

describe Raven::Logger do
  it "should log to a given IO" do
    io = IO::Memory.new

    logger = Raven::Logger.new(io)
    logger.fatal("Oh noes!")

    io.to_s.should match(/FATAL -- sentry: Oh noes!\n\Z/)
  end
end

require "../spec_helper"
require "log/spec"

describe Raven::Logger do
  it "should log to a given IO" do
    log = Raven::Logger.for(Raven::Logger::PROGNAME)

    Raven::Logger.capture(builder: Raven::Logger.builder) do |logs|
      log.info { "Oh YAZ!" }
      log.fatal { "Oh noes!" }

      logs.check(:info, "Oh YAZ!")
      logs.next(:fatal, "Oh noes!")
    end
  end
end

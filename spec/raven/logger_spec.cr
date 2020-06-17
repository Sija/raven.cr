require "../spec_helper"
require "log/spec"

describe Raven::Logger do
  it "should log to a given backend" do
    backend = Log::MemoryBackend.new

    logger = Raven::Logger.new(backend, :info)
    logger.info { "Oh YAZ!" }
    logger.fatal { "Oh noes!" }

    logs = Log::EntriesChecker.new(backend.entries)
    logs.check(:info, "Oh YAZ!")
    logs.next(:fatal, "Oh noes!")
  end
end

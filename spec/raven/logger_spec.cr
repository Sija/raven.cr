require "../spec_helper"
require "log/spec"

describe Raven::Logger do
  it "should log to a given backend" do
    backend = Log::MemoryBackend.new
    log = Raven::Logger.new(backend, :info)

    log.info { "Oh YAZ!" }
    log.fatal { "Oh noes!" }

    logs = Log::EntriesChecker.new(backend.entries)

    logs.check(:info, "Oh YAZ!")
    logs.next(:fatal, "Oh noes!")
  end

  it "should log to a given IO" do
    io = IO::Memory.new
    backend = Log::IOBackend.new(io)
    log = Raven::Logger.new(backend, :info)

    log.info { "Oh YAZ!" }
    log.fatal { "Oh noes!" }

    io.to_s.should match(/INFO - sentry: Oh YAZ!\n/)
    io.to_s.should match(/FATAL - sentry: Oh noes!\n\Z/)
  end
end

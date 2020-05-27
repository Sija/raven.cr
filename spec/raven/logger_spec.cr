require "../spec_helper"

describe Raven::Logger do
  it "should log to a given IO" do
    backend = Log::MemoryBackend.new
    log = Raven::Logger.new(backend, Log::Severity::Info)

    log.info { "Oh YAZ!" }
    log.fatal { "Oh noes!" }

    backend.entries.map { |e| {e.severity, e.source, e.message} }.should eq([
      {Log::Severity::Info, "sentry", "Oh YAZ!"},
      {Log::Severity::Fatal, "sentry", "Oh noes!"},
    ])
  end
end

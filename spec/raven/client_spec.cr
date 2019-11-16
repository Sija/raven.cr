require "../spec_helper"

class ClientTest < Raven::Client
  def generate_auth_header
    super
  end

  def get_message_from_exception(event)
    super
  end
end

def build_configuration
  Raven::Configuration.new
    .tap(&.dsn = "dummy://12345:67890@sentry.localdomain:3000/sentry/42")
end

def with_client
  yield ClientTest.new(build_configuration)
end

describe Raven::Client do
  context "#get_message_from_exception" do
    it "returns exception class with message" do
      event = Raven::Event.from(Exception.new("Foo!"))
      with_client do |client|
        client.get_message_from_exception(event.to_hash).should eq "Exception: Foo!"
      end
    end
  end

  context "#generate_auth_header" do
    it "generates an auth header" do
      with_client do |client|
        client.configuration.dsn = "dummy://12345:67890@sentry.io/42"
        client.generate_auth_header.should eq "Sentry sentry_version=#{Raven::Client::PROTOCOL_VERSION}, sentry_client=#{Raven::Client::USER_AGENT}, sentry_key=12345, sentry_secret=67890"
      end
    end

    it "generates an auth header without a secret (Sentry 9)" do
      with_client do |client|
        client.configuration.dsn = "dummy://66260460f09b5940498e24bb7ce093a0@sentry.io/42"
        client.generate_auth_header.should eq "Sentry sentry_version=#{Raven::Client::PROTOCOL_VERSION}, sentry_client=#{Raven::Client::USER_AGENT}, sentry_key=66260460f09b5940498e24bb7ce093a0"
      end
    end
  end

  context "#send_event" do
    it "sends event to the configured transport" do
      with_client do |client|
        client.transport.should be_a(Raven::Transport::Dummy)
        transport = client.transport.as(Raven::Transport::Dummy)
        transport.events.tap do |events|
          events.size.should eq(0)
          client.send_event(Raven::Event.from(build_exception))
          events.size.should eq(1)
        end
      end
    end

    it "skips sending event when before_send callback returns nil" do
      with_client do |client|
        client.configuration.before_send { nil }
        transport = client.transport.as(Raven::Transport::Dummy)
        transport.events.tap do |events|
          events.size.should eq(0)
          client.send_event(Raven::Event.from(build_exception))
          events.size.should eq(0)
        end
      end
    end

    it "sends event serialized as JSON hash" do
      event = Raven::Event.from(build_exception)
      with_client do |client|
        client.configuration.encoding = :json
        client.send_event(event)
        transport = client.transport.as(Raven::Transport::Dummy)
        transport.events.last.tap do |last_event|
          last_event[:options].should eq({:content_type => "application/json"})
          last_event[:data].should be_a(String)
          data = JSON.parse(last_event[:data].as(String))
          data.as_h?.should_not be_nil
          data["event_id"].should eq(event.id)
        end
      end
    end

    it "sends event compressed with GZIP" do
      event = Raven::Event.from(build_exception)
      with_client do |client|
        client.configuration.encoding = :gzip
        client.send_event(event)
        transport = client.transport.as(Raven::Transport::Dummy)
        transport.events.last.tap do |last_event|
          last_event[:options].should eq({:content_type => "application/octet-stream"})
          last_event[:data].should be_a(String)
          io = IO::Memory.new(last_event[:data].as(String))
          Gzip::Reader.open(io) do |gzip|
            data = JSON.parse(gzip.gets_to_end)
            data.as_h?.should_not be_nil
            data["event_id"].should eq(event.id)
          end
        end
      end
    end
  end

  context "#send_feedback" do
    it "sends feedback to the configured transport" do
      with_client do |client|
        transport = client.transport.as(Raven::Transport::Dummy)
        transport.feedback.tap do |feedback|
          feedback.size.should eq(0)
          feedback_data = {
            "name"     => "Foobar",
            "email"    => "foo@bar.org",
            "comments" => "...",
          }
          client.send_feedback("foo_id", feedback_data)
          feedback.size.should eq(1)
          feedback.last.should eq({
            :event_id => "foo_id",
            :data     => feedback_data,
          })
        end
      end
    end
  end
end

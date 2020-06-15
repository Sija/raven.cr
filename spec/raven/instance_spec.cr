require "../spec_helper"
require "log/spec"

module Raven::Test
  class BaseException < ::Exception; end

  class SubException < BaseException; end
end

private class InstanceTest < Raven::Instance
  getter last_sent_event : Raven::Event?

  def send_event(event, hint = nil)
    super.tap do
      @last_sent_event = event
    end
  end
end

def build_instance_configuration
  Raven::Configuration.new.tap do |config|
    config.dsn = "dummy://12345:67890@sentry.localdomain:3000/sentry/42"
    config.logger = Raven::Logger.for(Raven::Logger::PROGNAME)
  end
end

def with_instance(context = nil)
  yield InstanceTest.new(context, build_instance_configuration)
end

describe Raven::Instance do
  describe "#context" do
    it "is Raven.context by default" do
      with_instance do |instance|
        instance.context.should be(Raven.context)
      end
    end

    context "initialized with a context" do
      it "is not Raven.context" do
        with_instance(Raven::Context.new) do |instance|
          instance.context.should_not be(Raven.context)
        end
      end
    end
  end

  describe "#capture" do
    it "returns the generated event" do
      with_instance do |instance|
        returned = instance.capture("Test message", foo: "bar")
        returned.should be_a(Raven::Event)
        returned.as?(Raven::Event).try(&.message).should eq("Test message")
      end
    end

    it "yields the event to a passed block" do
      with_instance do |instance|
        instance.capture("Test message", id: "foo", logger: "bar") do |event|
          event.message.should eq("Test message")
          event.id.should eq("foo")
          event.logger.should eq("bar")
        end
      end
    end

    {% for key in %i(user extra tags) %}
      context "with {{key.id}} context specified" do
        it "merges context hierarchy" do
          with_instance do |instance|
            Raven::Context.clear!
            Raven.{{key.id}}_context(foo: :foo, bar: :bar)

            instance.capture("Test message", {{key.id}}: {bar: "baz"}) do |event|
              event.{{key.id}}.should eq({:foo => :foo, :bar => "baz"})
            end
          end
        end

        it "use passed values only within the block" do
          with_instance do |instance|
            Raven::Context.clear!
            Raven.{{key.id}}_context(will: :stay_there)
            ctx = Raven.{{key.id}}_context(foo: :foo, bar: :bar) do
              instance.capture("Test message", {{key.id}}: {bar: "baz"}) do |event|
                event.{{key.id}}.should eq({
                  :will => :stay_there,
                  :foo => :foo,
                  :bar => "baz"
                })
              end
            end
            ctx.should eq({:will => :stay_there})
            Raven.{{key.id}}_context.should be(ctx)
          end
        end
      end
    {% end %}

    context "with String" do
      it "sends the result of Event.from" do
        with_instance do |instance|
          instance.capture("Test message", id: "foo", logger: "bar")
          instance.last_sent_event.try(&.message).should eq("Test message")
          instance.last_sent_event.try(&.id).should eq("foo")
          instance.last_sent_event.try(&.logger).should eq("bar")
        end
      end
    end

    context "with Exception" do
      it "sends the result of Event.from" do
        with_instance do |instance|
          instance.capture(build_exception, id: "foo", logger: "bar")
          instance.last_sent_event.try(&.id).should eq("foo")
          instance.last_sent_event.try(&.logger).should eq("bar")
        end
      end

      it "ignores Raven::Error" do
        with_instance do |instance|
          instance.capture(Raven::Error.new).should be_false
          instance.last_sent_event.should be_nil
        end
      end

      context "for an excluded exception type" do
        context "defined by string type" do
          it "returns false for a class match" do
            with_instance do |instance|
              instance.configuration.excluded_exceptions << "Raven::Test::BaseException"
              instance.capture(Raven::Test::BaseException.new).should be_false
            end
          end

          it "returns Raven::Event for an undefined exception class" do
            with_instance do |instance|
              instance.configuration.excluded_exceptions << "Raven::Test::NonExistentException"
              instance.capture(Raven::Test::BaseException.new).should be_a(Raven::Event)
            end
          end
        end

        context "defined by class type" do
          it "returns false for a class match" do
            with_instance do |instance|
              instance.configuration.excluded_exceptions << Raven::Test::BaseException
              instance.capture(Raven::Test::BaseException.new).should be_false
            end
          end

          it "returns false for a sub class match" do
            with_instance do |instance|
              instance.configuration.excluded_exceptions << Raven::Test::BaseException
              instance.capture(Raven::Test::SubException.new).should be_false
            end
          end
        end
      end
    end

    context "when async" do
      it "sends the result of Event.from" do
        with_instance do |instance|
          async_event = nil
          instance.configuration.async = ->(e : Raven::Event) { async_event = e }

          instance.capture("Test message", foo: "bar")
          instance.last_sent_event.should be_nil
          async_event.try(&.message).should eq("Test message")
        end
      end
    end

    context "when async raises an exception" do
      it "sends the result of Event.capture via fallback" do
        with_instance do |instance|
          instance.configuration.async = ->(_e : Raven::Event) { raise ArgumentError.new }

          instance.capture("Test message", id: "foo", logger: "bar")
          instance.last_sent_event.try(&.message).should eq("Test message")
          instance.last_sent_event.try(&.id).should eq("foo")
          instance.last_sent_event.try(&.logger).should eq("bar")
        end
      end
    end

    context "with should_capture callback" do
      it "sends the result of Event.capture according to the result of should_capture" do
        with_instance do |instance|
          instance.configuration.should_capture = ->(_obj : Exception | String) { false }

          instance.capture(build_exception).should be_false
          instance.last_sent_event.should be_nil
        end
      end
    end
  end

  describe "#report_status" do
    not_ready_message = "Raven #{Raven::VERSION} configured not to capture errors"
    ready_message = "Raven #{Raven::VERSION} ready to catch errors"

    it "logs a ready message when configured" do
      with_instance do |instance|
        instance.configuration.silence_ready = false

        Raven::Logger.capture(builder: Raven::Logger.builder) do |logs|
          instance.report_status

          logs.check(:info, ready_message)
        end
      end
    end

    it "logs nothing if 'silence_ready' option is true" do
      with_instance do |instance|
        instance.configuration.silence_ready = true

        Raven::Logger.capture(builder: Raven::Logger.builder) do |logs|
          instance.report_status

          logs.empty
        end
      end
    end

    it "logs not ready message when not configured" do
      with_instance do |instance|
        instance.configuration.silence_ready = false
        instance.configuration.dsn = "dummy://foo"

        Raven::Logger.capture(builder: Raven::Logger.builder) do |logs|
          instance.report_status

          logs.check(:info, /#{not_ready_message}/)
        end
      end
    end

    it "logs not ready message if the config does not send in current environment" do
      with_instance do |instance|
        instance.configuration.silence_ready = false
        instance.configuration.environments = %w(production)

        Raven::Logger.capture(builder: Raven::Logger.builder) do |logs|
          instance.report_status

          logs.check(:info, "#{not_ready_message}: Not configured to send/capture in environment 'default'")
        end
      end
    end
  end

  describe ".last_event_id" do
    it "sends the result of Event.capture" do
      with_instance do |instance|
        event = instance.capture("Test message")
        instance.last_sent_event.try(&.id).should eq(event.as?(Raven::Event).try(&.id))
      end
    end
  end
end

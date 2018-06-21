require "../spec_helper"

module Raven::Test
  module ExceptionTag; end

  class BaseException < ::Exception; end

  class SubException < BaseException; end

  class TaggedException < BaseException
    include ExceptionTag
  end
end

private class InstanceTest < Raven::Instance
  getter last_sent_event : Raven::Event?

  def send_event(event)
    super.tap do
      @last_sent_event = event
    end
  end
end

private class LoggerTest < Raven::Logger
  getter infos = [] of String

  def info(message, *args)
    super.tap do
      @infos << message
    end
  end
end

def build_configuration
  Raven::Configuration.new.tap do |config|
    config.dsn = "dummy://12345:67890@sentry.localdomain:3000/sentry/42"
    config.logger = LoggerTest.new(nil)
  end
end

def with_instance(context = nil)
  yield InstanceTest.new(context, build_configuration)
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
          instance.last_sent_event.try(&.message).should eq("Exception: Raven.cr test exception")
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

          pending "returns false for a top class match" do
            with_instance do |instance|
              instance.configuration.excluded_exceptions << "::Raven::Test::BaseException"
              instance.capture(Raven::Test::BaseException.new).should be_false
            end
          end

          pending "returns false for a sub class match" do
            with_instance do |instance|
              instance.configuration.excluded_exceptions << "Raven::Test::BaseException"
              instance.capture(Raven::Test::SubException.new).should be_false
            end
          end

          pending "returns false for a tagged class match" do
            with_instance do |instance|
              instance.configuration.excluded_exceptions << "Raven::Test::ExceptionTag"
              instance.capture(Raven::Test::TaggedException.new).should be_false
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

          pending "returns false for a tagged class match" do
            with_instance do |instance|
              instance.configuration.excluded_exceptions << Raven::Test::ExceptionTag
              instance.capture(Raven::Test::TaggedException.new).should be_false
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

        instance.report_status
        instance.logger.as(LoggerTest).infos.should contain(ready_message)
      end
    end

    it "logs nothing if 'silence_ready' option is true" do
      with_instance do |instance|
        instance.configuration.silence_ready = true

        instance.report_status
        instance.logger.as(LoggerTest).infos.should_not contain(ready_message)
      end
    end

    it "logs not ready message when not configured" do
      with_instance do |instance|
        instance.configuration.silence_ready = false
        instance.configuration.dsn = "dummy://foo"

        instance.report_status
        instance.logger.as(LoggerTest).infos.first.should contain(not_ready_message)
      end
    end

    it "logs not ready message if the config does not send in current environment" do
      with_instance do |instance|
        instance.configuration.silence_ready = false
        instance.configuration.environments = %w(production)

        instance.report_status
        instance.logger.as(LoggerTest).infos.should contain(
          "#{not_ready_message}: Not configured to send/capture in environment 'default'"
        )
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

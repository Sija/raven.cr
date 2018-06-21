require "../spec_helper"

module Raven::Test
  class Exception < ::Exception; end
end

def with_event(clear = true, **opts)
  if clear
    Raven::Context.clear!
    Raven::BreadcrumbBuffer.clear!
  end
  event = Raven::Event.new(**opts)
  yield event
end

def with_event_hash(**opts)
  with_event(**opts) do |event|
    yield event.to_hash
  end
end

def exception_value_from_event_hash(hash, index)
  ex_values = hash.to_any_json[:exception, :values].as(Array)
  ex_values[index].as(Hash)
end

describe Raven::Event do
  context "with fully implemented event" do
    opts = {
      message: "test",
      level:   :warning,
      logger:  "foo",
      tags:    {
        foo: "bar",
      },
      extra: {
        my_custom_variable: "value",
      },
      server_name: "foo.local",
      release:     "721e41770371db95eee98ca2707686226b993eda",
      environment: "production",
    }

    with_event_hash(**opts) do |hash|
      it "has message" do
        hash[:message].should eq("test")
      end

      it "has level" do
        hash[:level].should eq("warning")
      end

      it "has logger" do
        hash[:logger].should eq("foo")
      end

      it "has server name" do
        hash[:server_name].should eq("foo.local")
      end

      it "has release" do
        hash[:release].should eq("721e41770371db95eee98ca2707686226b993eda")
      end

      it "has environment" do
        hash[:environment].should eq("production")
      end

      it "has tag data" do
        hash[:tags].should eq({:foo => "bar"})
      end

      it "has extra data" do
        hash[:extra].should eq({:my_custom_variable => "value"})
      end

      it "has platform" do
        hash[:platform].should eq("crystal")
      end

      it "has SDK" do
        hash[:sdk].should eq({:name => "raven.cr", :version => Raven::VERSION})
      end

      it "has server os" do
        hash[:contexts].as(Hash)[:os].as(Hash).keys.should eq([:name, :version, :build, :kernel_version])
      end

      it "has runtime" do
        hash[:contexts].as(Hash)[:runtime].as(Hash)[:name].should match(/crystal/i)
      end
    end
  end

  context "with user context specified" do
    Raven.user_context({"id" => "hello"})

    it "adds user data" do
      with_event_hash(clear: false) do |hash|
        hash[:user].should eq({"id" => "hello"})
      end
    end
  end

  context "with tags context specified" do
    Raven.tags_context({"key" => "value"})

    it "merges tags data" do
      with_event_hash(tags: {"foo" => "bar"}, clear: false) do |hash|
        hash[:tags].should eq({"key" => "value", "foo" => "bar"})
      end
    end
  end

  context "with extra context specified" do
    Raven.extra_context({"key" => "value"})

    it "merges extra data" do
      with_event_hash(extra: {"foo" => "bar"}, clear: false) do |hash|
        hash[:extra].should eq({"key" => "value", "foo" => "bar"})
      end
    end
  end

  context "with configuration tags specified" do
    config = Raven::Configuration.new
    config.tags = {"key" => "value"}
    config.release = "custom"
    config.current_environment = "custom"

    it "merges tags data" do
      with_event_hash(tags: {"foo" => "bar"}, configuration: config) do |hash|
        hash[:tags].should eq({"key" => "value", "foo" => "bar"})
        hash[:release].should eq("custom")
        hash[:environment].should eq("custom")
      end
    end
  end

  context "with configuration tags unspecified" do
    config = Raven::Configuration.new

    it "should not persist tags between unrelated events" do
      with_event_hash(tags: {"foo" => "bar"}, configuration: config) do
        with_event_hash(configuration: config) do |hash2|
          hash2[:tags].should eq({} of String => String)
        end
      end
    end
  end

  context "tags hierarchy respected" do
    config = Raven::Configuration.new
    config.tags = {
      "configuration_context_event_key" => "configuration_value",
      "configuration_context_key"       => "configuration_value",
      "configuration_event_key"         => "configuration_value",
      "configuration_key"               => "configuration_value",
    }

    Raven.tags_context({
      "configuration_context_event_key" => "context_value",
      "configuration_context_key"       => "context_value",
      "context_event_key"               => "context_value",
      "context_key"                     => "context_value",
    })

    event_tags = {
      "configuration_context_event_key" => "event_value",
      "configuration_event_key"         => "event_value",
      "context_event_key"               => "event_value",
      "event_key"                       => "event_value",
    }

    it "merges tags data" do
      with_event_hash(tags: event_tags, configuration: config, clear: false) do |hash|
        hash[:tags].should eq({
          "configuration_context_event_key" => "event_value",
          "configuration_context_key"       => "context_value",
          "configuration_event_key"         => "event_value",
          "context_event_key"               => "event_value",
          "configuration_key"               => "configuration_value",
          "context_key"                     => "context_value",
          "event_key"                       => "event_value",
        })
      end
    end
  end

  {% for key in %i(user extra tags) %}
    context "with {{key.id}} context specified" do
      Raven::Context.clear!

      Raven.{{key.id}}_context({
        "context_event_key" => "context_value",
        "context_key"       => "context_value",
      })

      event_context = {
        "context_event_key" => "event_value",
        "event_key"         => "event_value",
      }

      it "prioritizes event context" do
        with_event_hash({{key.id}}: event_context, clear: false) do |hash|
          hash[:{{key.id}}].should eq({
            "context_event_key" => "event_value",
            "context_key"       => "context_value",
            "event_key"         => "event_value",
          })
        end
      end
    end
  {% end %}

  context "merging exception context into extra hash" do
    exception = Exception.new
    exception.__raven_context.merge!({
      "context_event_key" => "context_value",
      "context_key"       => "context_value",
    })
    event_context = {
      "context_event_key" => "event_value",
      "event_key"         => "event_value",
    }
    hash = Raven::Event.from(exception, extra: event_context).to_hash

    it "prioritizes event context over request context" do
      hash[:extra].should eq({
        "context_event_key" => "event_value",
        "context_key"       => "context_value",
        "event_key"         => "event_value",
      })
    end
  end

  describe ".from" do
    context "with String" do
      message = "This is a message"
      hash = Raven::Event.from(message).to_hash

      it "returns an event" do
        Raven::Event.from(message).should be_a(Raven::Event)
      end

      it "sets the message to the value passed" do
        hash[:message].should eq(message)
      end

      it "has level ERROR" do
        hash[:level].should eq("error")
      end

      it "accepts an options hash" do
        Raven::Event.from(message, logger: "logger").logger.should eq("logger")
      end

      it "accepts a stacktrace" do
        src_path = File.expand_path("../../src", __DIR__)
        lib_path = File.expand_path("../../lib/bar", __DIR__)

        backtrace = [
          "#{src_path}/foo.cr:1:7 in 'foo_function'",
          "#{lib_path}/src/bar.cr:3:10 in 'bar_function'",
          "#{__DIR__}/some/relative/path:123:4 in 'naughty_function'",
          "/absolute/path/to/some/file:22:3 in 'function_name'",
          "some/relative/path:1412:1 in 'other_function'",
        ]

        event = Raven::Event.from(message, backtrace: backtrace)
        stacktrace = event.interface(:stacktrace).as(Raven::Interface::Stacktrace)

        frames = stacktrace.to_hash[:frames]
        frames.size.should eq(5)

        frames[0].as(Hash)[:lineno].should eq(1412)
        frames[0].as(Hash)[:colno].should eq(1)
        frames[0].as(Hash)[:function].should eq("other_function")
        frames[0].as(Hash)[:abs_path].should eq("some/relative/path")
        frames[0].as(Hash)[:filename].should eq(frames[0][:abs_path])
        frames[0].as(Hash)[:package].should be_nil
        frames[0].as(Hash)[:in_app].should be_false

        frames[1].as(Hash)[:lineno].should eq(22)
        frames[1].as(Hash)[:colno].should eq(3)
        frames[1].as(Hash)[:function].should eq("function_name")
        frames[1].as(Hash)[:abs_path].should eq("/absolute/path/to/some/file")
        frames[1].as(Hash)[:filename].should be_nil
        frames[1].as(Hash)[:package].should be_nil
        frames[1].as(Hash)[:in_app].should be_false

        frames[2].as(Hash)[:lineno].should eq(123)
        frames[2].as(Hash)[:colno].should eq(4)
        frames[2].as(Hash)[:function].should eq("naughty_function")
        frames[2].as(Hash)[:abs_path].should eq("#{__DIR__}/some/relative/path")
        frames[2].as(Hash)[:filename].should eq("spec/raven/some/relative/path")
        frames[2].as(Hash)[:package].should be_nil
        frames[2].as(Hash)[:in_app].should be_false

        frames[3].as(Hash)[:lineno].should eq(3)
        frames[3].as(Hash)[:colno].should eq(10)
        frames[3].as(Hash)[:function].should eq("bar_function")
        frames[3].as(Hash)[:abs_path].should eq("#{lib_path}/src/bar.cr")
        frames[3].as(Hash)[:filename].should eq("lib/bar/src/bar.cr")
        frames[3].as(Hash)[:package].should eq("bar")
        frames[3].as(Hash)[:in_app].should be_false

        frames[4].as(Hash)[:lineno].should eq(1)
        frames[4].as(Hash)[:colno].should eq(7)
        frames[4].as(Hash)[:function].should eq("foo_function")
        frames[4].as(Hash)[:abs_path].should eq("#{src_path}/foo.cr")
        frames[4].as(Hash)[:filename].should eq("src/foo.cr")
        frames[4].as(Hash)[:package].should be_nil
        frames[4].as(Hash)[:in_app].should be_true
      end
    end

    context "with Exception" do
      message = "This is a message"
      exception = Exception.new(message)
      hash = Raven::Event.from(exception).to_hash

      it "returns an event" do
        Raven::Event.from(exception).should be_a(Raven::Event)
      end

      it "sets the message to the exception's message and type" do
        hash[:message].should eq("Exception: #{message}")
      end

      it "has level ERROR" do
        hash[:level].should eq("error")
      end

      it "uses the exception class name as the exception type" do
        exception_value_from_event_hash(hash, 0)[:type].should eq("Exception")
      end

      it "uses the exception message as the exception value" do
        exception_value_from_event_hash(hash, 0)[:value].should eq(message)
      end

      it "does not belong to a module" do
        exception_value_from_event_hash(hash, 0)[:module].should eq("")
      end

      context "for a nested exception type" do
        exception = Raven::Test::Exception.new(message)
        hash = Raven::Event.from(exception).to_hash

        it "sends the module name as part of the exception info" do
          exception_value_from_event_hash(hash, 0)[:module].should eq("Raven::Test")
        end
      end

      context "when the exception has a cause" do
        exception = build_exception_with_cause
        hash = Raven::Event.from(exception).to_hash

        it "captures the cause" do
          hash[:exception].as(Hash)[:values].as(Array).size.should eq(2)
        end
      end

      context "when the exception has nested causes" do
        exception = build_exception_with_two_causes
        hash = Raven::Event.from(exception).to_hash

        it "captures nested causes" do
          hash[:exception].as(Hash)[:values].as(Array).size.should eq(3)
        end
      end

      it "accepts an options hash" do
        Raven::Event.from(exception, id: "foo").id.should eq("foo")
      end

      it "adds an annotation to extra hash" do
        Raven.annotate_exception(exception, foo: "bar")
        Raven::Event.from(exception).extra.should eq({:foo => "bar"})
      end

      it "accepts a release" do
        Raven::Event.from(exception, release: "1.0").release.should eq("1.0")
      end

      it "accepts a fingerprint" do
        event = Raven::Event.from(exception, fingerprint: ["{{ default }}", "foo"])
        event.fingerprint.should eq(["{{ default }}", "foo"])
      end

      it "accepts a logger" do
        Raven::Event.from(exception, logger: "root").logger.should eq("root")
      end
    end
  end
end

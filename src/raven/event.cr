require "uuid"

module Raven
  class Event
    include Mixin::InitializeWith

    # Event severity.
    enum Severity
      DEBUG
      INFO
      WARNING
      ERROR
      FATAL
    end

    # Structure passed to `Configuration#before_send` callback.
    record Hint, exception : Exception?, message : String?

    # See Sentry server default limits at
    # https://github.com/getsentry/sentry/blob/master/src/sentry/conf/server.py
    MAX_MESSAGE_SIZE_IN_BYTES = 1024 * 8

    # A string representing the platform the SDK is submitting from.
    #
    # This will be used by the Sentry interface to customize
    # various components in the interface.
    PLATFORM = "crystal"

    # Information about the SDK sending the event.
    SDK = {name: "raven.cr", version: Raven::VERSION}

    # `Hash` type returned by `#to_hash`.
    alias HashType = Hash(AnyHash::JSON::Key, AnyHash::JSON::Value)

    # Hexadecimal string representing a uuid4 value.
    #
    # NOTE: The length is exactly 32 characters (no dashes!)
    property id : String

    # Indicates when the logging record was created (in the Sentry SDK).
    property timestamp : Time

    # The record severity. Defaults to `:error`.
    property level : Severity?

    # ditto
    def level=(severity : Symbol)
      @level = Severity.parse(severity.to_s)
    end

    # The name of the logger which created the record.
    property logger : String?

    # The name of the transaction (or culprit) which caused this exception.
    property culprit : String?

    # :nodoc:
    def culprit=(frame : Interface::Stacktrace::Frame)
      self.culprit = self.class.format_culprit_name(frame)
    end

    # Identifies the host SDK from which the event was recorded.
    property server_name : String?

    # The release version of the application.
    #
    # NOTE: This value will generally be something along the lines of
    # the git SHA for the given project.
    property release : String?

    # An array of strings used to dictate the deduplication of this event.
    #
    # NOTE: A value of `{{ default }}` will be replaced with the built-in behavior,
    # thus allowing you to extend it, or completely replace it.
    property fingerprint : Array(String) { [] of String }

    # The environment name, such as `production` or `staging`.
    property environment : String?

    # A list of relevant modules and their versions.
    property modules : Hash(String, String)?

    property context : Context
    property configuration : Configuration
    property breadcrumbs : BreadcrumbBuffer

    any_json_property :contexts, :user, :tags, :extra

    def self.from(ex : Exception, **options)
      {% for key in %i(user tags extra) %}
        ex_context = ex.@__raven_{{ key.id }}
        if options_context = options[{{ key }}]?
          options = options.merge({
            {{ key.id }}: ex_context.try(&.merge(options_context)) || options_context
          })
        else
          options = options.merge({
            {{ key.id }}: ex_context
          })
        end
      {% end %}

      new(**options).tap do |event|
        ex.callstack ||= Exception::CallStack.new
        add_exception_interface(event, ex)
      end
    end

    def self.from(message : String, **options)
      new(**options).tap do |event|
        event.message = {message, options[:message_params]?}
      end
    end

    protected def self.format_culprit_name(frame)
      return unless frame
      parts = {
        [nil, frame.filename || frame.abs_path],
        ["in", frame.function],
        ["at line", frame.lineno],
      }
      parts.reject(&.last.nil?).flatten.compact.join ' '
    end

    protected def self.add_exception_interface(event, ex)
      exceptions = [ex] of Exception
      context = Set(UInt64){ex.object_id}
      backtraces = Set(UInt64).new

      while ex = ex.cause
        break if context.includes?(ex.object_id)
        exceptions << ex
        context << ex.object_id
      end
      exceptions.reverse!

      values = exceptions.map do |e|
        Interface::SingleException.new do |iface|
          iface.type = e.class.to_s
          iface.value = e.to_s
          iface.module = e.class.to_s.split("::")[0...-1].join("::")

          iface.stacktrace =
            if e.backtrace? && !backtraces.includes?(e.backtrace.object_id)
              backtraces << e.backtrace.object_id
              Interface::Stacktrace.new(backtrace: e.backtrace) do |stacktrace|
                event.culprit = stacktrace.culprit
              end
            end
        end
      end
      event.interface :exception, values: values
    end

    def initialize(**options)
      @interfaces = {} of Symbol => Interface
      @configuration = options[:configuration]? || Raven.configuration
      @breadcrumbs = options[:breadcrumbs]? || Raven.breadcrumbs
      @context = options[:context]? || Raven.context
      @id = UUID.random.hexstring
      @timestamp = Time.utc
      @level = Severity::ERROR
      @server_name = @configuration.server_name
      @release = @configuration.release
      @environment = @configuration.current_environment
      @modules = list_shard_specs if @configuration.send_modules?

      initialize_with **options

      contexts.merge! @context.contexts
      user.merge! @context.user, options[:user]?
      extra.merge! @context.extra, options[:extra]?
      tags.merge! @configuration.tags, @context.tags, options[:tags]?
    end

    def interface(name : Symbol)
      interface = Interface[name]
      @interfaces[interface.sentry_alias]?
    end

    def interface(name : Symbol, **options : Object)
      interface = Interface[name]
      @interfaces[interface.sentry_alias] = interface.new(**options)
    end

    def interface(name : Symbol, options : NamedTuple)
      interface(name, **options)
    end

    def interface(name : Symbol, **options, &block)
      interface = Interface[name]
      @interfaces[interface.sentry_alias] = interface.new(**options) do |iface|
        yield iface
      end
    end

    def interface(name : Symbol, options : NamedTuple, &block)
      interface(name, **options) { |iface| yield iface }
    end

    def message
      interface(:message).try &.as(Interface::Message).unformatted_message
    end

    def message=(message : String)
      interface :message, message: trim_message(message)
    end

    def message=(message_with_params : Enumerable | Indexable)
      message, params = message_with_params
      options = {
        message: trim_message(message),
        params:  params,
      }
      interface :message, **options
    end

    private def trim_message(message, ellipsis = " [...]")
      if message.size > MAX_MESSAGE_SIZE_IN_BYTES
        message = message.byte_slice(0, MAX_MESSAGE_SIZE_IN_BYTES - ellipsis.bytesize)
        message += ellipsis
      end
      message
    end

    def backtrace=(backtrace)
      interface(:stacktrace, backtrace: backtrace).tap do |stacktrace|
        self.culprit ||= stacktrace.as(Interface::Stacktrace).culprit
      end
    end

    def list_shard_specs
      shards_list = Raven.sys_command_compiled("shards list")
      return unless shards_list
      deps = shards_list.scan /\* (?<name>.+?) \((?<version>.+?)\)/m
      unless deps.empty?
        deps.to_h { |match| {match["name"], match["version"]} }
      end
    end

    def to_hash : HashType
      data = {
        event_id:    @id,
        timestamp:   @timestamp.to_utc.to_s("%FT%X"),
        level:       @level.try(&.to_s.downcase),
        platform:    PLATFORM,
        sdk:         SDK,
        logger:      @logger,
        culprit:     @culprit,
        server_name: @server_name,
        release:     @release,
        environment: @environment,
        fingerprint: @fingerprint,
        modules:     @modules,
        extra:       @extra,
        tags:        @tags,
        user:        @user,
        contexts:    @contexts,
        breadcrumbs: @breadcrumbs.empty? ? nil : @breadcrumbs.to_hash,
        message:     message,
      }.to_any_json

      @interfaces.each do |name, interface|
        data[name] = interface.to_hash
      end
      # data.compact!
      data.to_h
    end

    delegate :to_json, to: to_hash
  end
end

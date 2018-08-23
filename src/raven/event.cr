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

    def self.from(exc : Exception, **options)
      # FIXME: would be nice to be able to call
      # `event.initialize_with(exc_context)` somehow...
      exc_context = get_exception_context(exc)
      if extra = options[:extra]?
        options = options.merge(extra: exc_context.merge(extra))
      else
        options = options.merge(extra: exc_context)
      end

      new(**options).tap do |event|
        # Messages limited to 10kb
        event.message = "#{exc.class}: #{exc.message}".byte_slice(0, MAX_MESSAGE_SIZE_IN_BYTES)

        exc.callstack ||= CallStack.new
        add_exception_interface(event, exc)
      end
    end

    def self.from(message : String, **options)
      # Messages limited to 10kb
      message = message.byte_slice(0, MAX_MESSAGE_SIZE_IN_BYTES)

      new(**options).tap do |event|
        event.message = {message, options[:message_params]?}
      end
    end

    protected def self.get_exception_context(exc)
      exc.__raven_context
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

    protected def self.add_exception_interface(event, exc)
      exceptions = [exc] of Exception
      context = Set(UInt64).new({exc.object_id})
      backtraces = Set(UInt64).new

      while exc = exc.cause
        break if context.includes?(exc.object_id)
        exceptions << exc
        context << exc.object_id
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
      @timestamp = Time.now
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
      interface :message, message: message
    end

    def message=(message_with_params)
      options = {
        message: message_with_params.first,
        params:  message_with_params.last,
      }
      interface :message, **options
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
        deps.map { |match| {match["name"], match["version"]} }.to_h
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

    def to_json(json : JSON::Builder)
      to_hash.to_json(json)
    end
  end
end

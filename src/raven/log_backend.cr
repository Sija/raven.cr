require "log"
require "log/json"

module Raven
  # `::Log::Backend` recording logged messages.
  #
  # ```
  # Log.setup do |c|
  #   c.bind "*", :info, Log::IOBackend.new
  #   c.bind "*", :info, Raven::LogBackend.new(record_breadcrumbs: true)
  #   c.bind "*", :warn, Raven::LogBackend.new(capture_exceptions: true)
  #   c.bind "*", :fatal, Raven::LogBackend.new(capture_all: true)
  # end
  # ```
  class LogBackend < ::Log::Backend
    private BREADCRUMB_LEVELS = {
      :trace  => :debug,
      :debug  => :debug,
      :info   => :info,
      :notice => :info,
      :warn   => :warning,
      :error  => :error,
      :fatal  => :critical,
    } of ::Log::Severity => Breadcrumb::Severity

    private EXCEPTION_LEVELS = {
      :trace  => :debug,
      :debug  => :debug,
      :info   => :info,
      :notice => :info,
      :warn   => :warning,
      :error  => :error,
      :fatal  => :fatal,
    } of ::Log::Severity => Event::Severity

    # Records each logged entry as a breadcrumb.
    #
    # See `Raven.breadcrumbs`
    property? record_breadcrumbs : Bool

    # Captures `Exception` attached to the logged entry, if present.
    #
    # See `Raven.capture`
    property? capture_exceptions : Bool

    # Captures each logged entry.
    #
    # See `Raven.capture`
    property? capture_all : Bool

    # Default name of the root logger.
    #
    # See `Event#logger`, `Breadcrumb#category`
    property default_logger : String

    def initialize(
      dispatch_mode : ::Log::DispatchMode = :sync,
      *,
      @record_breadcrumbs = false,
      @capture_exceptions = false,
      @capture_all = false,
      @default_logger = "logger"
    )
      super(dispatch_mode)
    end

    protected delegate :ignored_logger?,
      to: Raven.configuration

    protected def deansify(message : String?) : String?
      message.try &.gsub(/\x1b[^m]*m/, "").presence
    end

    protected def record_breadcrumb(message, severity, timestamp, source, data = nil)
      level = BREADCRUMB_LEVELS[severity]?

      message = deansify(message)
      logger = source.presence || default_logger

      Raven.breadcrumbs.record do |crumb|
        crumb.message = message if message
        crumb.level = level if level
        crumb.timestamp = timestamp if timestamp
        crumb.category = logger
        crumb.data = data if data
      end
    end

    protected def capture_exception(exception, message, severity, timestamp, source, data = nil)
      level = EXCEPTION_LEVELS[severity]?

      message = deansify(message)
      logger = source.presence || default_logger

      if exception
        return if Raven.captured_exception?(exception)
      else
        exception, message = message, nil
        exception ||= "<empty>"
      end

      Raven.capture(exception) do |event|
        event.culprit = message if message
        event.level = level if level
        event.timestamp = timestamp if timestamp
        event.logger = logger
        event.tags = data if data
      end
    end

    def active?
      record_breadcrumbs? || capture?
    end

    def capture?
      capture_exceptions? || capture_all?
    end

    def write(entry : ::Log::Entry)
      return if !active? || ignored_logger?(entry.source)

      data = entry.context.extend(entry.data.to_h)
      data = data.empty? ? nil : JSON.parse(data.to_json).as_h # FIXME

      message = entry.message
      ex = entry.exception

      if capture?
        capture_exception(
          ex,
          message,
          entry.severity,
          entry.timestamp,
          entry.source,
          data,
        ) if ex || capture_all?
      end

      if record_breadcrumbs?
        if ex
          message += " -- (#{ex.class}): #{ex.message || "n/a"}"
        end
        record_breadcrumb(
          message,
          entry.severity,
          entry.timestamp,
          entry.source,
          data,
        )
      end
    end
  end
end

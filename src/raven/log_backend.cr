require "log"
require "log/json"

module Raven
  # `::Log::Backend` recording logged messages.
  #
  # ```
  # Log.setup do |c|
  #   c.bind "*", :info, Log::IOBackend.new
  #   c.bind "*", :info, Raven::LogBackend.new
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

    def initialize(
      *,
      @record_breadcrumbs = true,
      @capture_exceptions = false,
      @capture_all = false
    )
    end

    protected delegate :ignored_logger?,
      to: Raven.configuration

    protected def deansify(message : String?) : String?
      message.try &.gsub(/\x1b[^m]*m/, "")
    end

    protected def record_breadcrumb(message, severity, timestamp, source, data = nil)
      level = BREADCRUMB_LEVELS[severity]?

      message = deansify(message).presence
      logger = source.presence || "logger"

      Raven.breadcrumbs.record do |crumb|
        crumb.message = message
        crumb.level = level if level
        crumb.timestamp = timestamp if timestamp
        crumb.category = logger
        crumb.data = data if data
      end
    end

    protected def capture_exception(exception, message, severity, timestamp, source, data = nil)
      level = EXCEPTION_LEVELS[severity]?

      if exception.is_a?(String)
        exception = deansify(exception)
      end

      message = deansify(message).presence
      logger = source.presence || "logger"

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

    # ameba:disable Metrics/CyclomaticComplexity
    def write(entry : ::Log::Entry)
      return unless active?
      return if ignored_logger?(entry.source)

      data = entry.context.extend(entry.data.to_h)
      data = data.empty? ? nil : JSON.parse(data.to_json).as_h # FIXME

      message = entry.message
      ex = entry.exception

      if capture?
        capture_exception(
          ex ? ex : message,
          ex ? message : nil,
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

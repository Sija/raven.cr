module Raven
  module LogHelper
    protected delegate :ignored_logger?,
      to: Raven.configuration

    protected def deansify(message : String?) : String?
      message.try &.gsub(/\x1b[^m]*m/, "")
    end

    protected def record_breadcrumb(message, level, timestamp, source, data = nil)
      return if ignored_logger?(source)

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

    protected def capture_exception(exception, message, level, timestamp, source, data = nil)
      return if ignored_logger?(source)

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
  end
end

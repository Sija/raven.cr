module Raven
  module LogHelper
    protected def deansify(message) : String?
      case message
      when Nil       then nil
      when String    then message.gsub(/\x1b[^m]*m/, "")
      when Exception then deansify(message.message)
      else                deansify(message.to_s)
      end
    end

    protected def record_breadcrumb(message, level, timestamp, source, data = nil)
      return if Raven.configuration.ignored_logger?(source)
      Raven.breadcrumbs.record do |crumb|
        crumb.message = deansify(message).presence
        crumb.level = level if level
        crumb.timestamp = timestamp if timestamp
        crumb.category = source.presence || "logger"
        crumb.data = data if data
      end
    end
  end
end

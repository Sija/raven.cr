module Raven
  module BreadcrumbLogHelper
    protected def deansify(message) : String?
      case message
      when Nil       then nil
      when String    then message.gsub(/\x1b[^m]*m/, "")
      when Exception then deansify(message.message)
      else                deansify(message.to_s)
      end
    end

    protected def record_breadcrumb(level, timestamp, category, message) : Breadcrumb?
      return if Raven.configuration.ignored_logger?(category)
      Raven.breadcrumbs.record do |crumb|
        crumb.level = level
        crumb.timestamp = timestamp
        crumb.category = category.presence || "logger"
        crumb.message = deansify(message).presence
      end
    end
  end
end

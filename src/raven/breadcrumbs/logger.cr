require "logger"

module Raven::Breadcrumb::Logger
  private LOGGER_BREADCRUMB_LEVELS = {
    ::Logger::DEBUG => Severity::DEBUG,
    ::Logger::INFO  => Severity::INFO,
    ::Logger::WARN  => Severity::WARNING,
    ::Logger::ERROR => Severity::ERROR,
    ::Logger::FATAL => Severity::CRITICAL,
  }

  protected def self.ignored_logger?(progname)
    Raven.configuration.exclude_loggers.includes?(progname)
  end

  protected def record_breadcrumb(severity, datetime, progname, message)
    return if Logger.ignored_logger?(progname)
    Raven.breadcrumbs.record do |crumb|
      crumb.timestamp = datetime
      crumb.level = LOGGER_BREADCRUMB_LEVELS[severity]?
      crumb.category = progname || "logger"
      crumb.message = message
    end
  end
end

class Logger
  include Raven::Breadcrumb::Logger

  protected def self.deansify(message)
    case message
    when Nil       then nil
    when String    then message.gsub(/\x1b[^m]*m/, "")
    when Exception then deansify(message.message)
    else                deansify(message.to_s)
    end
  end

  private def write(severity, datetime, progname, message)
    record_breadcrumb(
      severity,
      datetime,
      self.class.deansify(progname),
      self.class.deansify(message),
    )
    previous_def
  end
end

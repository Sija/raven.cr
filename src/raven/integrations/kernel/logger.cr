require "logger"
require "../shared/breadcrumb_log_helper"

class Logger
  include Raven::BreadcrumbLogHelper

  private BREADCRUMB_LEVELS = {
    :debug => :debug,
    :info  => :info,
    :warn  => :warning,
    :error => :error,
    :fatal => :critical,
  } of ::Logger::Severity => Raven::Breadcrumb::Severity

  private def write(severity, datetime, progname, message)
    level = BREADCRUMB_LEVELS[severity]?

    record_breadcrumb(
      message,
      level,
      datetime,
      progname,
    )
    previous_def
  end
end

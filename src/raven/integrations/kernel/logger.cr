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
    record_breadcrumb(
      BREADCRUMB_LEVELS[severity]?,
      datetime,
      progname,
      message,
    )
    previous_def
  end
end

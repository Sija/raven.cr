require "logger"

# TODO: remove after/if https://github.com/crystal-lang/crystal/pull/9570 is merged
struct Log::Entry
  def initialize(@source : String, @severity : Severity, @message : String, @data : Log::Metadata, @exception : Exception?, @timestamp : Time)
  end
end

class Logger
  property :__raven_log_backend { Raven::LogBackend.new(record_breadcrumbs: true) }

  private def write(severity, datetime, progname, message)
    level = Log::Severity.parse?(severity.to_s) || Log::Severity::Debug
    data = Log::Metadata.new

    __raven_log_backend.write Log::Entry.new(
      source: progname.to_s,
      severity: level,
      message: message.to_s,
      data: data,
      exception: nil,
      timestamp: datetime,
    )
    previous_def
  end
end

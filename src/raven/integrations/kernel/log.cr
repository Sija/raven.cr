require "log"
require "../shared/breadcrumb_log_helper"

module Raven
  # ```
  # require "raven"
  # require "raven/integrations/kernel/log"
  # ```
  #
  # `::Log::Backend` recording logged messages as breadcrumbs.
  #
  # ```
  # Log.setup do |c|
  #   c.bind "*", :info, Log::IOBackend.new
  #   c.bind "*", :info, Raven::BreadcrumbLogBackend.new
  # end
  # ```
  class BreadcrumbLogBackend < ::Log::Backend
    include Raven::BreadcrumbLogHelper

    private BREADCRUMB_LEVELS = {
      :trace  => :debug,
      :debug  => :debug,
      :info   => :info,
      :notice => :info,
      :warn   => :warning,
      :error  => :error,
      :fatal  => :critical,
    } of ::Log::Severity => Raven::Breadcrumb::Severity

    def write(entry : ::Log::Entry)
      message = entry.message
      if ex = entry.exception
        message += " -- (#{ex.class}): #{ex.message || "n/a"}"
      end
      record_breadcrumb(
        BREADCRUMB_LEVELS[entry.severity]?,
        entry.timestamp,
        entry.source,
        message,
      )
    end
  end
end

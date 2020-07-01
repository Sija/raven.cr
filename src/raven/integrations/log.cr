require "log"
require "log/json"
require "./shared/log_helper"

module Raven
  # ```
  # require "raven"
  # require "raven/integrations/log"
  # ```
  #
  # `::Log::Backend` recording logged messages.
  #
  # ```
  # Log.setup do |c|
  #   c.bind "*", :info, Log::IOBackend.new
  #   c.bind "*", :info, Raven::LogBackend.new
  # end
  # ```
  class LogBackend < ::Log::Backend
    include LogHelper

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

    def active?
      record_breadcrumbs? || capture?
    end

    def capture?
      capture_exceptions? || capture_all?
    end

    def write(entry : ::Log::Entry)
      return unless active?

      data = entry.context.extend(entry.data.to_h)
      data = data.empty? ? nil : JSON.parse(data.to_json).as_h

      message = entry.message
      ex = entry.exception

      if capture?
        level = EXCEPTION_LEVELS[entry.severity]?
        capture_exception(
          ex ? ex : message,
          ex ? message : nil,
          level,
          entry.timestamp,
          entry.source,
          data,
        ) if ex || capture_all?
      end

      if record_breadcrumbs?
        level = BREADCRUMB_LEVELS[entry.severity]?
        if ex
          message += " –- (#{ex.class}): #{ex.message || "n/a"}"
        end
        record_breadcrumb(
          message,
          level,
          entry.timestamp,
          entry.source,
          data,
        )
      end
    end
  end
end

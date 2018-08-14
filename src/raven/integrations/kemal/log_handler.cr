require "kemal"

module Raven
  module Kemal
    # Kemal logger capturing all sent messages and requests as breadcrumbs.
    #
    # Optionally wraps another `::Kemal::BaseLogHandler` and forwards messages
    # to it.
    #
    # ```
    # Kemal.config.logger = Raven::Kemal::LogHandler.new(Kemal::LogHandler.new)
    # # ...
    # Kemal.config.add_handler(...)
    # # ...
    # Kemal.run
    # ```
    class LogHandler < ::Kemal::BaseLogHandler
      property? log_messages = true
      property? log_requests = true

      @wrapped : ::Kemal::BaseLogHandler?

      def initialize(@wrapped = nil)
      end

      def next=(handler : HTTP::Handler | HTTP::Handler::HandlerProc | Nil)
        @wrapped.try(&.next=(handler)) || (@next = handler)
      end

      private def elapsed_text(elapsed)
        millis = elapsed.total_milliseconds
        millis >= 1 ? "#{millis.round(2)}ms" : "#{(millis * 1000).round(2)}µs"
      end

      def call(context)
        time = Time.monotonic
        begin
          @wrapped.try(&.call(context)) || call_next(context)
        ensure
          if log_requests?
            elapsed = Time.monotonic - time

            Raven.breadcrumbs.record do |crumb|
              unless (200...400).includes? context.response.status_code
                crumb.level = :error
              end
              crumb.type = :http
              crumb.category = "kemal.request"
              crumb.data = {
                method:      context.request.method.upcase,
                url:         Kemal.build_request_url(context.request),
                status_code: context.response.status_code,
                elapsed:     elapsed_text(elapsed),
              }
            end
          end
          context
        end
      end

      def write(message)
        if log_messages?
          Raven.breadcrumbs.record do |crumb|
            crumb.category = "kemal"
            crumb.message = message.strip
          end
        end
        @wrapped.try &.write(message)
      end
    end
  end
end

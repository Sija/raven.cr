require "grip"

module Raven
  module Grip
    # Grip logger capturing all requests as breadcrumbs.
    #
    # ```
    # class Application < Grip::Application
    #   def initialize
    #     super(environment: "development")
    #
    #     # By default the router has 4 entries, you need to insert
    #     # a handler before the exception handler.
    #     #
    #     # [
    #     #   exception_handler,
    #     #   pipeline_handler,
    #     #   websocket_handler,
    #     #   http_handler,
    #     # ]
    #     router.insert(0, Raven::Grip::LogHandler.new(self))
    #   end
    # end
    # ```
    class LogHandler
      include HTTP::Handler

      def initialize(@application : ::Grip::Application)
      end

      private def elapsed_text(elapsed)
        millis = elapsed.total_milliseconds
        millis >= 1 ? "#{millis.round(2)}ms" : "#{(millis * 1000).round(2)}µs"
      end

      def call(context)
        time = Time.monotonic
        begin
          call_next(context)
        ensure
          elapsed = Time.monotonic - time

          Raven.breadcrumbs.record do |crumb|
            unless context.response.status_code.in?(100...400)
              crumb.level = :error
            end
            crumb.type = :http
            crumb.category = "grip.request"
            crumb.data = {
              method:      context.request.method.upcase,
              url:         Grip.build_request_url(@application, context.request),
              status_code: context.response.status_code,
              elapsed:     elapsed_text(elapsed),
            }
          end
        end
      end
    end
  end
end

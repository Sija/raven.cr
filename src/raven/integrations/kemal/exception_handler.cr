require "http"
require "../http/*"

module Raven
  module Kemal
    # Exception handler capturing all unhandled `Exception`s.
    # After capturing exception is re-raised.
    #
    # ```
    # Kemal.config.add_handler(Raven::Kemal::ExceptionHandler.new)
    # # ...
    # Kemal.run
    # ```
    class ExceptionHandler
      include HTTP::Handler
      include Raven::HTTPHandler

      # See `::Kemal::Route`
      CULPRIT_PATTERN_KEYS = %i(method path)

      def initialize(
        @culprit_pattern = "%{method} %{path}",
        @capture_data_for_methods = %w(POST PUT PATCH),
        @default_logger = "kemal"
      )
      end

      def build_raven_culprit_context(context : HTTP::Server::Context)
        context.route if context.route_found?
      end

      def build_raven_http_url(context : HTTP::Server::Context)
        Kemal.build_request_url(context.request)
      end

      def build_raven_http_data(context : HTTP::Server::Context)
        params = context.params
        AnyHash::JSON.new.merge!(params.body.to_h, params.json)
      end

      def on_raven_event(event : Raven::Event, context : HTTP::Server::Context)
        if context.responds_to?(:kemal_authorized_username?)
          event.user[:username] ||= context.kemal_authorized_username?
        end
      end
    end
  end
end

require "http"
require "../http/*"

module Raven
  module Grip
    # Exception handler capturing all unhandled `Exception`s.
    # After capturing exception is re-raised.
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
    #     router.insert(0, Raven::Grip::ExceptionHandler.new(self))
    #   end
    # end
    # ```
    class ExceptionHandler
      include HTTP::Handler
      include Raven::HTTPHandler

      # See `::Grip::Routers::Route`
      CULPRIT_PATTERN_KEYS = %i(method path)

      def initialize(
        @application : ::Grip::Application,
        @culprit_pattern = "%{method} %{path}",
        @capture_data_for_methods = %w(POST PUT PATCH),
        @default_logger = "grip",
      )
      end

      private def route_from_context(context : HTTP::Server::Context)
        router = @application.http_handler

        route = router.find_route(context.request.method, context.request.path)
        route = router.find_route("ALL", context.request.path) unless route.found?

        route if route.route_found?
      end

      def build_raven_culprit_context(context : HTTP::Server::Context)
        route_from_context(context)
      end

      def build_raven_http_url(context : HTTP::Server::Context)
        Grip.build_request_url(@application, context.request)
      end

      def build_raven_http_data(context : HTTP::Server::Context)
        unless params = context.parameters
          if route = route_from_context(context)
            params = ::Grip::Parsers::ParameterBox.new(context.request, route.params)
          end
        end
        if params
          AnyHash::JSON.new.merge!(params.body.to_h, params.json)
        end
      end
    end
  end
end

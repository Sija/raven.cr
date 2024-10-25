require "http"
require "../http/*"

module Raven
  module ActionController
    # Exception handler capturing all unhandled `Exception`s.
    # After capturing exception is re-raised.
    #
    # ```
    # server = HTTP::Server.new([
    #   # ...
    #   ActionController::ErrorHandler.new(production: true),
    #   Raven::ActionController::ErrorHandler.new,
    #   # ...
    # ])
    # ```
    class ErrorHandler
      include HTTP::Handler
      include Raven::HTTPHandler

      # See `::HTTP::Request`
      CULPRIT_PATTERN_KEYS = %i(method path)

      def initialize(
        @culprit_pattern = "%{method} %{path}",
        @capture_data_for_methods = %w(POST PUT PATCH),
        @default_logger = "action-controller",
      )
      end

      def build_raven_culprit_context(context : HTTP::Server::Context)
        context.request
      end

      def build_raven_http_url(context : HTTP::Server::Context)
        ActionController.build_request_url(context.request)
      end

      def build_raven_http_data(context : HTTP::Server::Context)
        ::ActionController::Base.extract_params(context).to_h
      end
    end
  end
end

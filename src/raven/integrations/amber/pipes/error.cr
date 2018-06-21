require "http"
require "../../http/*"

module Raven
  module Amber
    module Pipe
      # Error pipe capturing all unhandled `Exception`s.
      # After capturing exception is re-raised.
      #
      # ```
      # Amber::Server.configure do |app|
      #   pipeline :web do
      #     # ...
      #     plug Amber::Pipe::Error.new
      #     plug Raven::Amber::Pipe::Error.new
      #     # ...
      #   end
      # end
      # ```
      #
      # NOTE: Need to be plugged after `::Amber::Pipe::Error`.
      class Error < ::Amber::Pipe::Base
        include Raven::HTTPHandler

        # See `::Amber::Route`
        CULPRIT_PATTERN_KEYS = %i(verb resource controller action valve scope trail)

        def initialize(
          @culprit_pattern = "%{verb} %{controller}#%{action} (%{valve})",
          @capture_data_for_methods = %w(POST PUT PATCH),
          @default_logger = "amber"
        )
        end

        def build_raven_culprit_context(context : HTTP::Server::Context)
          request = context.request
          request.route if request.valid_route?
        end

        def build_raven_http_url(context : HTTP::Server::Context)
          Amber.build_request_url(context.request)
        end

        def build_raven_http_data(context : HTTP::Server::Context)
          context.params.to_h
        end
      end
    end
  end
end

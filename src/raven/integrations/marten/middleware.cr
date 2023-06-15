module Raven
  module Marten
    # Sentry middleware for Marten.
    #
    # In order to be used, this middleware should be added to the `middleware` Marten setting (ideally at the beginning
    # of the middleware array):
    #
    # ```
    # Marten.configure do |config|
    #   config.middleware = [
    #     Raven::Marten::Middleware,
    #     Marten::Middleware::GZip,
    #     Marten::Middleware::XFrameOptions,
    #     Marten::Middleware::StrictTransportSecurity,
    #   ]
    # end
    # ```
    class Middleware < ::Marten::Middleware
      def call(request : ::Marten::HTTP::Request, get_response : Proc(::Marten::HTTP::Response)) : ::Marten::HTTP::Response
        get_response.call
      rescue error
        case error
        when ::Marten::HTTP::Errors::NotFound, ::Marten::Routing::Errors::NoResolveMatch
          capture(request, error)
        else
          raise error
        end
      end

      private CAPTURE_DATA_FOR_METHODS = %w(POST PUT PATCH)

      private def build_full_url(request)
        String.build do |url|
          url << request.scheme
          url << "://"
          url << request.host
          url << ":#{request.port}" if !["80", "443"].includes?(request.port)
          url << request.full_path
        end
      end

      private def capture(request, error)
        Raven.capture(error) do |event|
          data = if CAPTURE_DATA_FOR_METHODS.includes?(request.method)
                   prepare_data(request.data)
                 else
                   nil
                 end

          event.culprit = "#{request.method} #{request.path}"
          event.logger ||= "marten"
          event.interface :http, {
            headers:      request.headers.to_h,
            cookies:      prepare_cookies(request.cookies),
            method:       request.method,
            url:          build_full_url(request),
            query_string: request.query_params.as_query,
            data:         data,
          }
        end
      end

      private def prepare_cookies(cookies)
        cookies.to_stdlib.to_h.join("; ") { |_, cookie| cookie.to_cookie_header }
      end

      private def prepare_data(data)
        prepared_data = {} of String => Array(String)

        data.each do |k, v|
          prepared_data[k] = v.map(&.to_s)
        end

        prepared_data
      end
    end
  end
end

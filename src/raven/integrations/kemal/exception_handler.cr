require "http"

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

      private def headers_to_hash(headers : HTTP::Headers)
        headers.each_with_object(AnyHash::JSON.new) do |(k, v), hash|
          hash[k] = v.size == 1 ? v.first : v
        end
      end

      def call(context)
        call_next context
      rescue ex
        Raven.capture(ex) do |event|
          request = context.request
          event.logger ||= "kemal"
          event.interface :http, {
            headers:      headers_to_hash(request.headers),
            method:       request.method.upcase,
            url:          Kemal.build_request_url(request),
            query_string: request.query,
          }
        end
        # Raven.annotate_exception exception, ...
        # pp ex
        raise ex
      end
    end
  end
end

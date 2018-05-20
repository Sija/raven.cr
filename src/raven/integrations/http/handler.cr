module Raven
  module HTTPHandler
    CULPRIT_PATTERN_KEYS = [] of Symbol | String

    # See `CULPRIT_PATTERN_KEYS`
    property culprit_pattern : String?
    property capture_data_for_methods = %w(POST PUT PATCH)
    property default_logger : String?

    protected def culprit_from(context)
      {% begin %}
        {% keys = @type.constant(:CULPRIT_PATTERN_KEYS) %}
        {% if !keys || keys.empty? %}
          culprit_pattern
        {% else %}
          keys = {
            {% for key in keys %}
              "{{key.id}}": context.{{key.id}},
            {% end %}
          }
          culprit_pattern.try &.%(keys)
        {% end %}
      {% end %}
    end

    protected def headers_to_hash(headers : HTTP::Headers)
      headers.each_with_object(AnyHash::JSON.new) do |(k, v), hash|
        hash[k] = v.join ", "
      end
    end

    protected def cookies_to_string(cookies : HTTP::Cookies)
      cookies.to_h.map(&.last.to_cookie_header).join "; "
    end

    abstract def build_raven_culprit_context(context : HTTP::Server::Context)
    abstract def build_raven_http_url(context : HTTP::Server::Context)
    abstract def build_raven_http_data(context : HTTP::Server::Context)

    def on_raven_event(event : Raven::Event, context : HTTP::Server::Context)
    end

    def call(context : HTTP::Server::Context)
      call_next(context)
    rescue ex
      Raven.capture(ex) do |event|
        request = context.request
        method = request.method

        build_raven_culprit_context(context).try do |obj|
          culprit_from(obj).try do |culprit|
            event.culprit = culprit
          end
        end
        default_logger.try do |logger|
          event.logger ||= logger
        end
        if capture_data_for_methods.includes?(method)
          data = build_raven_http_data(context)
        end
        event.interface :http, {
          headers:      headers_to_hash(request.headers),
          cookies:      cookies_to_string(request.cookies),
          method:       method,
          url:          build_raven_http_url(context),
          query_string: request.query,
          data:         data,
        }
        on_raven_event event, context
      end
      raise ex
    end
  end
end

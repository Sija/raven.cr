require "http/client"

module Raven
  class Transport::HTTP < Transport
    class Error < Error
      property response : ::HTTP::Client::Response

      def initialize(@response)
        message = @response.headers["X-Sentry-Error"]? || @response.status_message
        super(message)
      end
    end

    property client : ::HTTP::Client { build_client }

    private def build_client
      ssl = configuration.ssl
      ssl = configuration.scheme == "https" if ssl.nil?
      ::HTTP::Client.new(configuration.host.not_nil!, configuration.port, ssl).tap do |client|
        client.before_request do |request|
          request.headers["User-Agent"] = Client::USER_AGENT
        end
        if timeout = configuration.connect_timeout
          client.connect_timeout = timeout
        end
        if timeout = configuration.read_timeout
          client.read_timeout = timeout
        end
      end
    end

    def send_feedback(event_id, data)
      headers = ::HTTP::Headers.new
      # https://github.com/getsentry/sentry-swift/blob/7e0ae98ad49c16331a43c9a58b03be3e56c7a5a3/Sources/SentryEndpoint.swift#L154
      if origin = configuration.dsn
        headers["Origin"] = origin
      end
      params = ::HTTP::Params.build do |form|
        form.add "eventId", event_id
        form.add "dsn", configuration.dsn
      end
      path = String.build do |str|
        str << configuration.scheme << "://" << configuration.host
        str << ':' << configuration.port if configuration.port
        str << configuration.path << "/api/embed/error-page/"
        str << '?' << params
      end
      logger.debug "HTTP Transport connecting to #{path}"
      ::HTTP::Client.post_form(path, data, headers).tap do |response|
        raise Error.new response unless response.success?
      end
    end

    def send_event(auth_header, data, **options)
      unless configuration.capture_allowed?
        logger.debug "Event not sent: #{configuration.error_messages}"
        return
      end
      logger.debug "HTTP Transport connecting to #{configuration.dsn}"

      project_id = configuration.project_id
      path = configuration.path.try &.chomp '/'

      headers = ::HTTP::Headers{
        "X-Sentry-Auth" => auth_header,
        "Content-Type"  => options[:content_type],
      }
      if configuration.encoding.gzip?
        headers["Content-Encoding"] = "gzip"
      end
      client.post("#{path}/api/#{project_id}/store/", headers, data).tap do |response|
        raise Error.new response unless response.success?
      end
    end
  end
end

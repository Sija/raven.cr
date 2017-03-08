require "http/client"

module Raven
  class Transport::HTTP < Transport
    property client : ::HTTP::Client { build_client }

    private def build_client
      ::HTTP::Client.new(configuration.host.not_nil!, configuration.port).tap do |client|
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
      response = client.post "#{path}/api/#{project_id}/store/", headers, data
      unless response.success?
        raise Error.new response.headers["X-Sentry-Error"]? || response.status_message
      end
      response
    end
  end
end

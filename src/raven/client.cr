require "base64"
require "json"
require "zlib"

module Raven
  # Encodes events and sends them to the Sentry server.
  class Client
    PROTOCOL_VERSION = 7
    USER_AGENT       = "raven.cr/#{Raven::VERSION}"

    property configuration : Configuration
    delegate logger, to: configuration

    @state : State
    @processors : Array(Processor)

    getter transport : Transport do
      case configuration.scheme
      when "http", "https"
        Transport::HTTP.new(configuration)
      when "dummy"
        Transport::Dummy.new(configuration)
      else
        raise "Unknown transport scheme '#{configuration.scheme}'"
      end
    end

    def initialize(@configuration)
      @state = State.new
      @processors = [] of Processor

      @configuration.processors.each do |klass|
        @processors << klass.new(self)
      end
    end

    def send_feedback(event_id : String, data : Hash)
      transport.send_feedback(event_id, data)
    end

    def send_event(event : Event | Event::HashType)
      event = event.is_a?(Event) ? event.to_hash : event
      unless @state.should_try?
        failed_send nil, event
        return
      end
      logger.info "Sending event #{event[:event_id]} to Sentry"

      content_type, encoded_data = encode(event)
      begin
        options = {content_type: content_type}
        transport.send_event(generate_auth_header, encoded_data, **options).tap do
          successful_send
        end
      rescue e
        failed_send e, event
      end
    end

    private def encode(data)
      data = @processors.reduce(data) { |v, p| p.process(v) }

      io = IO::Memory.new
      data.to_json(io)
      io.rewind

      case configuration.encoding
      when .gzip?
        io_gzipped = IO::Memory.new
        Gzip::Writer.open(io_gzipped) do |gzip|
          IO.copy(io, gzip)
        end
        io_gzipped.rewind
        {"application/octet-stream", io_gzipped}
      when .json?
        {"application/json", io}
      else
        raise "Invalid configuration encoding"
      end
    end

    private def generate_auth_header
      fields = {
        sentry_version: PROTOCOL_VERSION,
        sentry_client:  USER_AGENT,
        sentry_key:     configuration.public_key,
      }
      if secret_key = configuration.secret_key
        fields = fields.merge(sentry_secret: secret_key)
      end
      "Sentry " + fields.map { |key, value| "#{key}=#{value}" }.join(", ")
    end

    private def successful_send
      @state.success
    end

    private def failed_send(e, event)
      @state.failure
      if e
        logger.error "Unable to record event with remote Sentry server \
          (#{e.class} - #{e.message}): #{e.backtrace[0..10].join('\n')}"
      else
        logger.error "Not sending event due to previous failure(s)"
      end

      message = event[:message]? || "<no message value>"
      logger.error "Failed to submit event: #{message}"

      configuration.transport_failure_callback.try &.call(event)
    end
  end
end

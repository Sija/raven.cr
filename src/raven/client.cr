require "base64"
require "json"
require "compress/gzip"

module Raven
  # Encodes events and sends them to the Sentry server.
  class Client
    PROTOCOL_VERSION = 7
    USER_AGENT       = "raven.cr/#{Raven::VERSION}"

    property configuration : Configuration

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
      if ex = configuration.validate!
        Log.debug {
          "Client#send_feedback with event id '#{event_id}' failed: #{ex.error_messages}"
        }
        return false
      end
      transport.send_feedback(event_id, data)
    end

    def send_event(event : Event | Event::HashType, hint : Event::Hint? = nil)
      if ex = configuration.validate!
        Log.debug {
          "Client#send_event with event '#{event}' failed: #{ex.error_messages}"
        }
        return false
      end
      if event.is_a?(Event)
        configuration.before_send.try do |before_send|
          event = before_send.call(event, hint)
          unless event
            Log.info { "Discarded event because before_send returned nil" }
            return
          end
        end
      end
      event = event.is_a?(Event) ? event.to_hash : event
      unless @state.should_try?
        failed_send nil, event
        return
      end
      Log.info { "Sending event #{event[:event_id]} to Sentry" }

      content_type, encoded_data = encode(event)
      begin
        options = {content_type: content_type}
        transport.send_event(generate_auth_header, encoded_data, **options).tap do
          successful_send
        end
      rescue ex
        failed_send ex, event
      end
    end

    private def encode(data)
      data = @processors.reduce(data) do |v, processor|
        processor.process(v)
      end

      io = IO::Memory.new
      data.to_json(io)
      io.rewind

      case configuration.encoding
      in .gzip?
        io_gzipped = IO::Memory.new
        Compress::Gzip::Writer.open(io_gzipped) do |gzip|
          IO.copy(io, gzip)
        end
        io_gzipped.rewind
        {"application/octet-stream", io_gzipped}
      in .json?
        {"application/json", io}
      end
    end

    private def generate_auth_header
      fields = {
        :sentry_version => PROTOCOL_VERSION,
        :sentry_client  => USER_AGENT,
        :sentry_key     => configuration.public_key,
      }
      if secret_key = configuration.secret_key
        fields[:sentry_secret] = secret_key
      end
      "Sentry " + fields.join(", ") { |key, value| "#{key}=#{value}" }
    end

    private def get_message_from_exception(event)
      values = event.to_any_json[:exception, :values]?.try &.as?(Array)
      if ex = values.try(&.first?).try &.as?(Hash)
        type, value = ex[:type]?, ex[:value]?
        "#{type}: #{value}" if type && value
      end
    end

    private def get_log_message(event)
      event[:message]? || get_message_from_exception(event) || "<no message value>"
    end

    private def successful_send
      @state.success
    end

    private def failed_send(ex, event)
      if ex
        @state.failure
        Log.warn(exception: ex) { "Unable to record event with remote Sentry server" }
      else
        Log.warn { "Not sending event due to previous failure(s)" }
      end

      message = get_log_message(event)
      Log.warn { "Failed to submit event: #{message}" }

      configuration.transport_failure_callback.try &.call(event)
    end
  end
end

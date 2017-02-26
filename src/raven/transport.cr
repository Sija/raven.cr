module Raven
  abstract class Transport
    property configuration : Configuration
    delegate logger, to: configuration

    def initialize(@configuration)
    end

    abstract def send_event(auth_header, data, **options)
  end
end

require "./transports/*"

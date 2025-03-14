require "grip"

module Raven
  # ```
  # require "raven"
  # require "raven/integrations/grip"
  # ```
  #
  # It's recommended to enable `Configuration#async` when using Grip.
  #
  # ```
  # Raven.configure do |config|
  #   # ...
  #   config.async = true
  # end
  # ```
  module Grip
    # Returns full URL string for `HTTP::Request`.
    def self.build_request_url(app : ::Grip::Application, req : HTTP::Request)
      String.build do |url|
        url << (app.ssl ? "https" : "http") << "://" << req.headers["Host"]? << req.resource
      end
    end
  end
end

Raven::Configuration::IGNORE_DEFAULT << Grip::Exceptions::NotFound

require "./grip/*"

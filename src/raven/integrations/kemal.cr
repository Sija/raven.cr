require "kemal"

module Raven
  # ```
  # require "raven"
  # require "raven/integrations/kemal"
  # ```
  #
  # It's recommended to enable `Configuration#async` when using Kemal.
  #
  # ```
  # Raven.configure do |config|
  #   # ...
  #   config.async = true
  #   config.current_environment = Kemal.config.env
  # end
  # ```
  module Kemal
    # Returns full URL string for `HTTP::Request`.
    def self.build_request_url(req : HTTP::Request)
      String.build do |url|
        url << ::Kemal.config.scheme << "://" << req.headers["Host"]? << req.resource
      end
    end
  end
end

Raven::Configuration::IGNORE_DEFAULT << Kemal::Exceptions::RouteNotFound

require "./kemal/*"

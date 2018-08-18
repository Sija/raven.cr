require "amber"

module Raven
  # ```
  # require "raven/integrations/amber"
  # ```
  #
  # It's recommended to enable `Configuration#async` when using Amber.
  #
  # ```
  # Raven.configure do |config|
  #   # ...
  #   config.async = true
  #   config.current_environment = Amber.env.to_s
  # end
  # ```
  module Amber
    # Returns full URL string for `HTTP::Request`.
    def self.build_request_url(req : HTTP::Request)
      String.build do |url|
        url << ::Amber::Server.instance.scheme << "://" << req.host_with_port << req.resource
      end
    end
  end
end

Raven::Configuration::IGNORE_DEFAULT << Amber::Exceptions::RouteNotFound

require "./amber/**"

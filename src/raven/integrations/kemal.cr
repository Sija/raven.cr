require "kemal"

module Raven
  # ```
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
        url << ::Kemal.config.scheme << "://" << req.host_with_port << req.resource
      end
    end
  end
end

require "./kemal/*"

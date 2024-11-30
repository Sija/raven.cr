require "uri"
require "lucky"

module Raven
  # ```
  # require "raven"
  # require "raven/integrations/lucky"
  # ```
  #
  # It's recommended to enable `Configuration#async` when using Lucky.
  #
  # ```
  # Raven.configure do |config|
  #   # ...
  #   config.async = true
  #   config.current_environment = Lucky::Env.name
  # end
  # ```
  module Lucky
    # Returns full URL string for `HTTP::Request`.
    def self.build_request_url(req : HTTP::Request)
      base_uri = URI.parse(::Lucky::RouteHelper.settings.base_uri)
      String.build do |url|
        # TODO: Use just `::Lucky::RouteHelper.settings.base_uri` if possible
        url << base_uri.scheme << "://" << req.headers["Host"]? << req.resource
      end
    end
  end
end

Raven::Configuration::IGNORE_DEFAULT << Lucky::RouteNotFoundError

require "./lucky/**"

require "action-controller"

module Raven
  # ```
  # require "raven"
  # require "raven/integrations/action-controller"
  # ```
  #
  # It's recommended to enable `Configuration#async` when using ActionController.
  #
  # ```
  # Raven.configure do |config|
  #   # ...
  #   config.async = true
  # end
  # ```
  module ActionController
    def self.build_request_url(req : HTTP::Request)
      "#{::ActionController::Support.request_protocol(req)}://#{req.headers["Host"]?}#{req.resource}"
    end
  end
end

require "./action-controller/*"

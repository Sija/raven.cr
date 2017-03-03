require "kemal"

module Raven
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

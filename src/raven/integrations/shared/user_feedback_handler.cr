module Raven
  module UserFeedbackHandler
    def call(context : HTTP::Server::Context)
      call_next(context)
    rescue ex
      raise ex unless Raven.configuration.capture_allowed?(ex)
      context.response.tap do |response|
        response.status_code = 500
        response.print render_view(ex)
      end
      context
    end

    abstract def render_view(ex)
  end
end

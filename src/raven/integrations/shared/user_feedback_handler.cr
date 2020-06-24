module Raven
  module UserFeedbackHandler
    def call(context : HTTP::Server::Context)
      call_next(context)
    rescue ex
      raise ex unless Raven.configuration.capture_allowed?(ex)
      context.response.tap do |response|
        if response.closed?
          Log.warn {
            "Couldn't render user feedback view because the response has already been closed"
          }
          next
        end
        response.status_code = 500
        response.print render_view(ex)
      end
      context
    end

    abstract def render_view(ex)
  end
end

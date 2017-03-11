module Raven
  module Kemal
    # Kemal handler capturing all `Exception`s handled by Raven
    # and presenting an error page with the user feedback dialog.
    #
    # Unhandled exceptions are re-raised.
    #
    # ```
    # Kemal.config.add_handler(Raven::Kemal::UserFeedbackHandler.new)
    # # ...
    # Kemal.run
    # ```
    #
    # NOTE: Should be added always as the first handler.
    class UserFeedbackHandler < ::Kemal::Handler
      def call(context)
        call_next context
      rescue ex
        raise ex unless Raven.configuration.capture_allowed? ex
        context.response.tap do |response|
          response.status_code = 500
          response.print render_view(ex)
        end
        context
      end

      protected def render_view(ex)
        {% begin %}
          render "{{__DIR__.id}}/views/user_feedback.ecr"
        {% end %}
      end
    end
  end
end

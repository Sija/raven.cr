require "../shared/*"

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
      include Raven::UserFeedbackHandler

      protected def render_view(ex)
        production? = ::Kemal.config.env == "production" # ameba:disable Lint/UselessAssign
        {% begin %}
          render "{{__DIR__.id}}/../shared/views/user_feedback.ecr"
        {% end %}
      end
    end
  end
end

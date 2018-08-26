require "../../shared/*"

module Raven
  module Amber
    module Pipe
      # Amber pipe capturing all `Exception`s handled by Raven
      # and presenting an error page with the user feedback dialog.
      #
      # Unhandled exceptions are re-raised.
      #
      # ```
      # Amber::Server.configure do |app|
      #   pipeline :web do
      #     # ...
      #     plug Amber::Pipe::Error.new
      #     plug Raven::Amber::Pipe::UserFeedback.new
      #     plug Raven::Amber::Pipe::Error.new
      #     # ...
      #   end
      # end
      # ```
      #
      # NOTE: Need to be plugged after `::Amber::Pipe::Error`, and
      # before `Raven::Amber::Pipe::Error`.
      class UserFeedback < ::Amber::Pipe::Base
        include ::Amber::Controller::Helpers::Render
        include Raven::UserFeedbackHandler

        protected def render_view(ex)
          production? = ::Amber.env.production? # ameba:disable Lint/UselessAssign
          {% begin %}
            render "user_feedback.ecr",
              path: "{{__DIR__.id}}/../../shared/views",
              folder: "",
              layout: false
          {% end %}
        end
      end
    end
  end
end

module Raven
  module Sidekiq
    # Exception handler capturing all unhandled `Exception`s.
    #
    # ```
    # cli = Sidekiq::CLI.new
    # server = cli.configure do |config|
    #   # ...
    #   config.error_handlers << Raven::Sidekiq::ExceptionHandler.new
    # end
    # cli.run(server)
    # ```
    class ExceptionHandler < ::Sidekiq::ExceptionHandler::Base
      def call(ex : Exception, context : Hash(String, JSON::Any)? = nil)
        Raven.capture(ex) do |event|
          event.logger ||= "sidekiq"
          event.extra.merge! context
        end
      end
    end
  end
end

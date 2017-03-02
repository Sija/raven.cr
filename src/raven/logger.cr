require "logger"

module Raven
  class Logger < ::Logger
    PROGNAME = "sentry"

    def self.new(*args, **options)
      super.tap do |logger|
        logger.progname = PROGNAME
      end
    end
  end
end

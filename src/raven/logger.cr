require "logger"

module Raven
  class Logger < ::Logger
    LOG_PREFIX = "** [Raven] "
    PROGNAME   = "sentry"

    def self.new(*args, **options)
      super.tap do |logger|
        logger.progname = PROGNAME

        original_formatter = logger.formatter
        logger.formatter = Formatter.new do |severity, datetime, progname, message, io|
          message = "#{LOG_PREFIX}#{message}"
          original_formatter.call severity, datetime, progname, message, io
        end
      end
    end
  end
end

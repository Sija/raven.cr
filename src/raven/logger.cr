require "log"

module Raven
  class Logger < ::Log
    PROGNAME = "sentry"

    def self.new(backend : Backend?, level : Severity = :info)
      new(PROGNAME, backend, level)
    end
  end
end

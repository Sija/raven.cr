require "log"

module Raven
  class Logger < ::Log
    PROGNAME = "sentry"

    def self.new(
      backend : Backend?,
      level : Severity,
      source : Nil = nil
    )
      new(PROGNAME, backend, level)
    end
  end
end

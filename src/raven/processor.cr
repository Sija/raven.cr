module Raven
  abstract class Processor
    STRING_MASK = "********"
    INT_MASK    = 0

    def initialize(@client : Client)
    end

    abstract def process(data)
  end
end

require "./processors/*"

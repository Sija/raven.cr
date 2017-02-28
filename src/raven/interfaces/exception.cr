module Raven
  class Interface::Exception < Interface
    property values : Array(SingleException)?

    def self.sentry_alias
      :exception
    end
  end
end

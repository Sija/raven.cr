module Raven
  class Interface::HTTP < Interface
    property! url : String
    property! method : String

    any_json_property :data, :query_string, :cookies, :headers, :env

    def self.sentry_alias
      :request
    end
  end
end

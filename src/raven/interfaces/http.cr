module Raven
  class Interface::HTTP < Interface
    property! url : String
    property! method : String
    property query_string : String?
    property cookies : String?

    any_json_property :env, :headers, :data

    def self.sentry_alias
      :request
    end
  end
end

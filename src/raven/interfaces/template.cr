module Raven
  class Interface::Template < Interface
    property abs_path : String?
    property filename : String?
    property pre_context : Array(String)?
    property context_line : String?
    property lineno : Int32?
    property post_context : Array(String)?

    def self.sentry_alias
      :template
    end
  end
end

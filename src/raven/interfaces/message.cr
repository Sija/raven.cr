module Raven
  class Interface::Message < Interface
    property! message : String
    property params : Array(String)?

    def self.sentry_alias
      :logentry
    end

    def unformatted_message
      if (params = @params) && !params.empty?
        message?.try(&.% params)
      else
        message?
      end
    end
  end
end

module Raven
  class Interface::Message < Interface
    property! message : String
    property params : Array(String)?

    def self.sentry_alias
      :logentry
    end

    def unformatted_message
      if params = @params
        params.empty? ? message? : message?.try { |m| m % params }
      else
        message?
      end
    end
  end
end

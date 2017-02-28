module Raven
  class Interface::Stacktrace < Interface
    property frames : Array(Frame) = [] of Frame

    def self.sentry_alias
      :stacktrace
    end

    # Not actually an interface, but I want to use the same style
    class Frame < Interface
      property abs_path : String?
      property function : String?
      property lineno : Int32?
      property colno : Int32?
      property? in_app : Bool?

      def under_src_path?
        return unless src_path = Configuration::SRC_PATH
        abs_path.try &.starts_with?(src_path)
      end

      def filename
        return nil unless path = abs_path

        prefix = nil
        prefix = Configuration::SRC_PATH if under_src_path?
        prefix ? path[prefix.to_s.chomp(File::SEPARATOR).size + 1..-1] : path
      end

      def to_hash
        data = super
        data[:filename] = filename
        data.to_h
      end
    end
  end
end

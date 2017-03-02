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

      def relative_path
        return nil unless path = abs_path
        return path unless path.starts_with?('/')
        return nil unless under_src_path?
        if prefix = Configuration::SRC_PATH
          path[prefix.chomp(File::SEPARATOR).size + 1..-1]
        end
      end

      def filename
        relative_path
      end

      def package
        relative_path.try &.match(Raven.configuration.modules_path_pattern).try do |match|
          match["name"]
        end
      end

      def to_hash
        data = super
        data[:filename] = filename
        data[:package] = package
        data.to_h
      end
    end
  end
end

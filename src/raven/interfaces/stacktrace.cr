module Raven
  class Interface::Stacktrace < Interface
    property frames : Array(Frame) = [] of Frame

    def self.sentry_alias
      :stacktrace
    end

    def backtrace=(backtrace)
      @frames.clear
      backtrace = Backtrace.parse(backtrace)
      backtrace.lines.reverse_each do |line|
        @frames << Frame.from_backtrace_line(line)
      end
    end

    def culprit : Frame?
      frames.reverse.find(&.in_app?) || frames.last?
    end

    # Not actually an interface, but I want to use the same style
    class Frame < Interface
      property abs_path : String?
      property filename : String?
      property function : String?
      property package : String?
      property lineno : Int32?
      property colno : Int32?
      property? in_app : Bool?

      def self.from_backtrace_line(line)
        new.tap do |frame|
          frame.abs_path = line.file
          frame.filename = line.relative_path
          frame.function = line.method
          frame.package = line.shard_name
          frame.lineno = line.number
          frame.colno = line.column
          frame.in_app = line.in_app?
        end
      end
    end
  end
end

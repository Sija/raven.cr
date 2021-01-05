module Raven
  class Interface::Stacktrace < Interface
    property frames : Array(Frame) = [] of Frame

    def self.sentry_alias
      :stacktrace
    end

    def backtrace=(backtrace : Backtracer::Backtrace)
      @frames.clear

      backtrace.frames.reverse_each do |frame|
        @frames << Frame.from_backtrace_frame(frame)
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
      property context_line : String?
      property pre_context : Array(String)?
      property post_context : Array(String)?
      property lineno : Int32?
      property colno : Int32?
      property? in_app : Bool?

      def self.from_backtrace_frame(line)
        new.tap do |frame|
          frame.abs_path = line.path
          frame.filename = line.relative_path
          frame.function = line.method
          frame.package = line.shard_name
          frame.lineno = line.lineno
          frame.colno = line.column
          frame.in_app = line.in_app?

          if context = line.context
            frame.pre_context, frame.context_line, frame.post_context =
              context.pre, context.line, context.post
          end
        end
      end
    end
  end
end

module Raven
  class Backtrace
    IGNORED_LINES_PATTERN = /_sigtramp|__crystal_(sigfault_handler|raise)|CallStack|caller:|raise<(.+?)>:NoReturn/

    class_getter default_filters = [
      ->(line : String) { line unless line.match(IGNORED_LINES_PATTERN) },
    ] of String -> String?

    getter lines : Array(Line)

    def self.parse(backtrace : Array(String), **options) : Backtrace
      filters = default_filters.dup
      options[:filters]?.try { |f| filters.concat(f) }

      filtered_lines = backtrace.map do |line|
        filters.reduce(line) do |nested_line, proc|
          proc.call(nested_line) || break
        end
      end.compact

      lines = filtered_lines.map &->Line.parse(String)
      new(lines)
    end

    def self.parse(backtrace : String, **options) : Backtrace
      parse(backtrace.lines, **options)
    end

    def initialize(@lines)
    end

    def_equals @lines

    def to_s(io : IO) : Nil
      @lines.join(io, '\n')
    end

    def inspect(io : IO) : Nil
      io << "#<Backtrace: "
      @lines.join(io, ", ", &.inspect(io))
      io << '>'
    end
  end
end

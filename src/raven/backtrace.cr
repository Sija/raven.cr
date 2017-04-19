module Raven
  class Backtrace
    IGNORED_LINES_PATTERN = /CallStack|caller:|raise<(.+?)>:NoReturn/

    class_getter default_filters = [
      ->(line : String) { line.match(IGNORED_LINES_PATTERN) ? nil : line },
    ] of String -> String?

    getter lines : Array(Line)

    def self.parse(backtrace : Array(String), **options)
      filters = default_filters.dup
      if f = options[:filters]?
        filters.concat(f)
      end

      filtered_lines = backtrace.map do |line|
        filters.reduce(line) do |nested_line, proc|
          proc.call(nested_line) || break
        end
      end.compact

      lines = filtered_lines.map do |unparsed_line|
        Line.parse(unparsed_line)
      end
      new(lines)
    end

    def self.parse(backtrace : String, **options)
      parse(backtrace.lines, **options)
    end

    def initialize(@lines)
    end

    def_equals @lines

    def to_s(io)
      @lines.join('\n', io)
    end

    def inspect(io)
      io << "<Backtrace: "
      @lines.join(", ", io, &.inspect(io))
      io << ">"
    end
  end
end

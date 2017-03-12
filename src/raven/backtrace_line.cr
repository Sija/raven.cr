module Raven
  # Handles backtrace parsing line by line
  struct Backtrace::Line
    # Examples:
    #
    # - `0x103a7bbee: __crystal_main at ??`
    # - `0x100e1ea72: *CallStack::unwind:Array(Pointer(Void)) at ??`
    # - `0x102dff5e7: *Foo::Bar#_baz:Foo::Bam at /home/fooBAR/code/awesome-shard.cr/lib/foo/src/foo/bar.cr 50:7`
    # - `0x102de9035: *Foo::Bar::bar_by_id<String>:Foo::Bam at /home/fooBAR/code/awesome-shard.cr/lib/foo/src/foo/bar.cr 29:9`
    # - `0x102cfe8f4: *Fiber#run:(IO::FileDescriptor | Nil) at /usr/local/Cellar/crystal-lang/0.20.5_2/src/fiber.cr 114:3`
    CRYSTAL_METHOD_FORMAT = /\*?(?<method>.*?) at (?<file>[^:]+)(?:\s(?<line>\d+)(?:\:(?<col>\d+))?)?$/

    # Examples:
    #
    # - `0x102cee376: ~procProc(Nil)@/usr/local/Cellar/crystal-lang/0.20.5_2/src/http/server.cr:148 at ??`
    # - `0x102ce57db: ~procProc(HTTP::Server::Context, String)@lib/kemal/src/kemal/route.cr:11 at ??`
    # - `0x1002d5180: ~procProc(HTTP::Server::Context, (File::PReader | HTTP::ChunkedContent | HTTP::Server::Response | HTTP::Server::Response::Output | HTTP::UnknownLengthContent | HTTP::WebSocket::Protocol::StreamIO | IO::ARGF | IO::Delimited | IO::FileDescriptor | IO::Hexdump | IO::Memory | IO::MultiWriter | IO::Sized | Int32 | OpenSSL::SSL::Socket | String::Builder | Zip::ChecksumReader | Zip::ChecksumWriter | Zlib::Deflate | Zlib::Inflate | Nil))@src/foo/bar/baz.cr:420 at ??`
    CRYSTAL_PROC_FORMAT = /\~(?<proc_method>[^@]+)@(?<proc_file>[^:]+)(?:\:(?<proc_line>\d+)) at \?+$/

    # See `CRYSTAL_PROC_FORMAT` and `CRYSTAL_METHOD_FORMAT`.
    #
    # Examples:
    #
    # - `0x103a7bbee: __crystal_main at ??`
    # - `0x102cfe8f4: *Fiber#run:(IO::FileDescriptor | Nil) at /usr/local/Cellar/crystal-lang/0.20.5_2/src/fiber.cr 114:3`
    # - `0x102cee376: ~procProc(Nil)@/usr/local/Cellar/crystal-lang/0.20.5_2/src/http/server.cr:148 at ??`
    CRYSTAL_INPUT_FORMAT = /^(?<addr>0x[a-z0-9]+): #{CRYSTAL_PROC_FORMAT + CRYSTAL_METHOD_FORMAT}/

    # The file portion of the line (such as `app/models/user.cr`).
    getter file : String?

    # The line number portion of the line.
    getter number : Int32?

    # The column number portion of the line.
    getter column : Int32?

    # The method of the line (such as index).
    getter method : String?

    private def self.empty_marker?(value)
      value =~ /^\?+$/
    end

    # Parses a single line of a given backtrace, where *unparsed_line* is
    # the raw line from `caller` or some backtrace.
    # Returns the parsed backtrace line.
    def self.parse(unparsed_line : String) : Line
      if match = unparsed_line.match(CRYSTAL_INPUT_FORMAT)
        file = match["proc_file"]? || match["file"]?
        file = nil if empty_marker?(file)
        number = match["proc_line"]? || match["line"]?
        column = match["col"]?
        method = match["proc_method"]? || match["method"]?
      end
      new(file, number.try(&.to_i), column.try(&.to_i), method)
    end

    def initialize(@file, @number, @column, @method)
    end

    def_equals_and_hash @file, @number, @column, @method

    # Reconstructs the line in a readable fashion
    def to_s(io)
      io << '`' << method << '`' if method
      if file
        io << " at " << file
        io << ':' << number if number
      end
    end

    def inspect(io)
      io << "<Line: " << self << ">"
    end

    def under_src_path?
      return unless src_path = Configuration::SRC_PATH
      file.try &.starts_with?(src_path)
    end

    def relative_path
      return unless path = file
      return path unless path.starts_with?('/')
      return unless under_src_path?
      if prefix = Configuration::SRC_PATH
        path[prefix.chomp(File::SEPARATOR).size + 1..-1]
      end
    end

    def shard_name
      relative_path
        .try &.match(Raven.configuration.modules_path_pattern)
        .try &.[]("name")
    end

    def in_app?
      !!(file =~ Raven.configuration.in_app_pattern)
    end
  end
end

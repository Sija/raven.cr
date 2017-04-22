module Raven
  # Handles backtrace parsing line by line
  struct Backtrace::Line
    # :nodoc:
    ADDR_FORMAT = /(?<addr>0x[a-f0-9]+)/i

    CALLSTACK_PATTERNS = {
      # Examples:
      #
      # - `0x103a7bbee: __crystal_main at ??`
      # - `0x100e1ea72: *CallStack::unwind:Array(Pointer(Void)) at ??`
      # - `0x102dff5e7: *Foo::Bar#_baz:Foo::Bam at /home/fooBAR/code/awesome-shard.cr/lib/foo/src/foo/bar.cr 50:7`
      # - `0x102de9035: *Foo::Bar::bar_by_id<String>:Foo::Bam at /home/fooBAR/code/awesome-shard.cr/lib/foo/src/foo/bar.cr 29:9`
      # - `0x102cfe8f4: *Fiber#run:(IO::FileDescriptor | Nil) at /usr/local/Cellar/crystal-lang/0.20.5_2/src/fiber.cr 114:3`
      CRYSTAL_METHOD: /^#{ADDR_FORMAT}: \*?(?<method>.*?) at (?<file>[^:]+)(?:\s(?<line>\d+)(?:\:(?<col>\d+))?)?$/,

      # Examples:
      #
      # - `0x102cee376: ~procProc(Nil)@/usr/local/Cellar/crystal-lang/0.20.5_2/src/http/server.cr:148 at ??`
      # - `0x102ce57db: ~procProc(HTTP::Server::Context, String)@lib/kemal/src/kemal/route.cr:11 at ??`
      # - `0x1002d5180: ~procProc(HTTP::Server::Context, (File::PReader | HTTP::ChunkedContent | HTTP::Server::Response | HTTP::Server::Response::Output | HTTP::UnknownLengthContent | HTTP::WebSocket::Protocol::StreamIO | IO::ARGF | IO::Delimited | IO::FileDescriptor | IO::Hexdump | IO::Memory | IO::MultiWriter | IO::Sized | Int32 | OpenSSL::SSL::Socket | String::Builder | Zip::ChecksumReader | Zip::ChecksumWriter | Zlib::Deflate | Zlib::Inflate | Nil))@src/foo/bar/baz.cr:420 at ??`
      CRYSTAL_PROC: /^#{ADDR_FORMAT}: \~(?<method>[^@]+)@(?<file>[^:]+)(?:\:(?<line>\d+)) at \?+$/,

      # Examples:
      #
      # - `[0x1057a9fab] *CallStack::print_backtrace:Int32 +107`
      # - `[0x105798aac] __crystal_sigfault_handler +60`
      # - `[0x7fff9ca0652a] _sigtramp +26`
      # - `[0x105cb35a1] GC_realloc +50`
      # - `[0x1057870bb] __crystal_realloc +11`
      # - `[0x1057d3ecc] *Pointer(UInt8)@Pointer(T)#realloc<Int32>:Pointer(UInt8) +28`
      # - `[0x105965e03] *Foo::Bar#bar!:Nil +195`
      # - `[0x10579f5c1] *naughty_bar:Nil +17`
      # - `[0x10579f5a9] *naughty_foo:Nil +9`
      # - `[0x10578706c] __crystal_main +2940`
      # - `[0x105798128] main +40`
      CRYSTAL_CRASH: /^\[#{ADDR_FORMAT}\] \*?(?<method>.*?) \+\d+(?: \((?<times>\d+) times\))?$/,
    }

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

    private def self.nil_on_empty(value)
      empty_marker?(value) ? nil : value
    end

    # Parses a single line of a given backtrace, where *unparsed_line* is
    # the raw line from `caller` or some backtrace.
    # Returns the parsed backtrace line.
    def self.parse(unparsed_line : String) : Line
      if CALLSTACK_PATTERNS.values.any? &.match(unparsed_line)
        file = nil_on_empty $~["file"]?
        number = $~["line"]?
        column = $~["col"]?
        method = $~["method"]?
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

    # FIXME: untangle it from global `Raven`.
    protected delegate :configuration, to: Raven

    def under_src_path?
      return unless src_path = configuration.src_path
      file.try &.starts_with?(src_path)
    end

    def relative_path
      return unless path = file
      return path unless path.starts_with?('/')
      return unless under_src_path?
      if prefix = configuration.src_path
        path[prefix.chomp(File::SEPARATOR).size + 1..-1]
      end
    end

    def shard_name
      relative_path
        .try &.match(configuration.modules_path_pattern)
        .try &.[]("name")
    end

    def in_app?
      !!(file =~ configuration.in_app_pattern)
    end
  end
end

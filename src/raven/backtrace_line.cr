module Raven
  # Handles backtrace parsing line by line
  struct Backtrace::Line
    # :nodoc:
    ADDR_FORMAT = /(?<addr>0x[a-f0-9]+)/i

    CALLSTACK_PATTERNS = {
      # Examples:
      #
      # - `lib/foo/src/foo/bar.cr:50:7 in '*Foo::Bar#_baz:Foo::Bam'`
      # - `lib/foo/src/foo/bar.cr:29:9 in '*Foo::Bar::bar_by_id<String>:Foo::Bam'`
      # - `/usr/local/Cellar/crystal-lang/0.24.1/src/fiber.cr:114:3 in '*Fiber#run:(IO::FileDescriptor | Nil)'`
      CRYSTAL_METHOD: /^(?<file>[^:]+)(?:\:(?<line>\d+)(?:\:(?<col>\d+))?)? in '\*?(?<method>.*?)'(?: at #{ADDR_FORMAT})?$/,

      # Examples:
      #
      # - `~procProc(Nil)@/usr/local/Cellar/crystal-lang/0.24.1/src/http/server.cr:148 at 0x102cee376`
      # - `~procProc(HTTP::Server::Context, String)@lib/kemal/src/kemal/route.cr:11 at 0x102ce57db`
      # - `~procProc(HTTP::Server::Context, (File::PReader | HTTP::ChunkedContent | HTTP::Server::Response | HTTP::Server::Response::Output | HTTP::UnknownLengthContent | HTTP::WebSocket::Protocol::StreamIO | IO::ARGF | IO::Delimited | IO::FileDescriptor | IO::Hexdump | IO::Memory | IO::MultiWriter | IO::Sized | Int32 | OpenSSL::SSL::Socket | String::Builder | Zip::ChecksumReader | Zip::ChecksumWriter | Zlib::Deflate | Zlib::Inflate | Nil))@src/foo/bar/baz.cr:420`
      CRYSTAL_PROC: /^(?<method>~[^@]+)@(?<file>[^:]+)(?:\:(?<line>\d+))(?: at #{ADDR_FORMAT})?$/,

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

      # Examples:
      #
      # - `HTTP::Server#handle_client<IO+>:Nil`
      # - `HTTP::Server::RequestProcessor#process<IO+, IO+, IO::FileDescriptor>:Nil`
      # - `Kemal::WebSocketHandler@HTTP::Handler#call_next<HTTP::Server::Context>:(Bool | HTTP::Server::Context | IO+ | Int32 | Nil)`
      # - `__crystal_main`
      CRYSTAL_METHOD_NO_DEBUG: /^(?<method>.+?)$/,
    }

    # The file portion of the line (such as `app/models/user.cr`).
    getter file : String?

    # The line number portion of the line.
    getter number : Int32?

    # The column number portion of the line.
    getter column : Int32?

    # The method of the line (such as index).
    getter method : String?

    # Parses a single line of a given backtrace, where *unparsed_line* is
    # the raw line from `caller` or some backtrace.
    #
    # Returns the parsed backtrace line on success or `nil` otherwise.
    def self.parse?(unparsed_line : String) : Line?
      return unless CALLSTACK_PATTERNS.values.any? &.match(unparsed_line)

      file = $~["file"]?
      file = nil if file.try(&.blank?)
      method = $~["method"]?
      method = nil if method.try(&.blank?)
      number = $~["line"]?.try(&.to_i?)
      column = $~["col"]?.try(&.to_i?)

      new(file, number, column, method)
    end

    # :ditto:
    def self.parse(unparsed_line : String) : Line
      parse?(unparsed_line) || \
         raise ArgumentError.new("Error parsing line: #{unparsed_line.inspect}")
    end

    def initialize(@file, @number, @column, @method)
    end

    def_equals_and_hash @file, @number, @column, @method

    # Reconstructs the line in a readable fashion
    def to_s(io : IO) : Nil
      io << '`' << @method << '`' if @method
      if @file
        io << " at " << @file
        io << ':' << @number if @number
        io << ':' << @column if @column
      end
    end

    def inspect(io : IO) : Nil
      io << "Backtrace::Line("
      to_s(io)
      io << ')'
    end

    # FIXME: untangle it from global `Raven`.
    protected delegate :configuration, to: Raven

    def under_src_path? : Bool
      return false unless src_path = configuration.src_path
      !!file.try(&.starts_with?(src_path))
    end

    def relative_path : String?
      return unless path = file
      return path unless path.starts_with?('/')
      return unless under_src_path?
      if prefix = configuration.src_path
        path[prefix.chomp(File::SEPARATOR).size + 1..-1]
      end
    end

    def shard_name : String?
      relative_path
        .try(&.match(configuration.modules_path_pattern))
        .try(&.["name"])
    end

    def in_app? : Bool
      !!(file =~ configuration.in_app_pattern)
    end

    def context : {Array(String), String, Array(String)}?
      context_lines = configuration.context_lines

      return unless context_lines && context_lines > 0
      return unless (lineno = @number) && lineno > 0
      return unless (filename = @file) && File.readable?(filename)

      lines = File.read_lines(filename)
      lineidx = lineno - 1

      if context_line = lines[lineidx]?
        pre_context = lines[Math.max(0, lineidx - context_lines), context_lines]
        post_context = lines[Math.min(lines.size, lineidx + 1), context_lines]
        {pre_context, context_line, post_context}
      end
    end
  end
end

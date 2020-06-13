require "uri"
require "json"

module Raven
  class Configuration
    # Array of required properties needed to be set, before
    # `Configuration` is considered valid.
    REQUIRED_OPTIONS = %i(host public_key project_id)

    # Array of exception classes that should never be sent.
    IGNORE_DEFAULT = [] of Exception.class | String

    # Note the order - we have to remove circular references and bad characters
    # before passing to other processors.
    DEFAULT_PROCESSORS = [
      Processor::RemoveCircularReferences,
      # Processor::RemoveStacktrace,
      Processor::Cookies,
      Processor::RequestMethodData,
      Processor::HTTPHeaders,
      Processor::UTF8Conversion,
      Processor::SanitizeData,
      Processor::Compact,
    ] of Processor.class

    # Array of default request methods for which data should be removed.
    DEFAULT_REQUEST_METHODS_FOR_DATA_SANITIZATION = %w(POST PUT PATCH)

    # Used in `#in_app_pattern`.
    property src_path : String? = {{ Process::INITIAL_PWD }}

    # Directories to be recognized as part of your app. e.g. if you
    # have an `engines` dir at the root of your project, you may want
    # to set this to something like `/(src|engines)/`
    property app_dirs_pattern = /src/

    # `Regex` pattern matched against `Backtrace::Line#file`.
    property in_app_pattern : Regex { /^(#{src_path}\/)?(#{app_dirs_pattern})/ }

    # Path pattern matching directories to be recognized as your app modules.
    # Defaults to standard Shards setup (`lib/shard-name/...`).
    property modules_path_pattern = %r{^lib/(?<name>[^/]+)}

    # Provide a `Proc` object that responds to `call` to send
    # events asynchronously, or pass `true` to to use standard `spawn`.
    #
    # ```
    # ->(event : Raven::Event) { spawn { Raven.send_event(event) } }
    # ```
    property async : Proc(Event, Nil)?

    # ditto
    def async=(block : Event -> _)
      @async = ->(event : Event) {
        block.call(event)
        nil
      }
    end

    # Sets `async` callback to either `Fiber`-based implementation (see below),
    # or `nil`, depending on the given *switch* value.
    #
    # ```
    # ->(event : Event) { spawn { Raven.send_event(event) } }
    # ```
    def async=(switch : Bool)
      return @async = nil unless switch
      @async = ->(event : Event) {
        spawn { Raven.send_event(event) }
        nil
      }
    end

    # Number of lines of code context to capture, or `nil` for none.
    property context_lines : Int32? = 5

    # Defaults to `SENTRY_ENVIRONMENT` variable if set,
    # `"default"` otherwise.
    property current_environment : String?

    # Encoding type for event bodies.
    enum Encoding
      JSON
      GZIP
    end

    # Encoding type for event bodies.
    property encoding : Encoding = Encoding::GZIP

    # Whitelist of environments that will send notifications to Sentry.
    property environments = [] of String

    # Logger "progname"s to exclude from breadcrumbs.
    #
    # Defaults to `[Raven::Logger::PROGNAME]`.
    #
    # NOTE: You should probably append to this rather than overwrite it.
    property exclude_loggers : Array(String)

    # Array of exception classes that should never be sent.
    #
    # See `IGNORE_DEFAULT`.
    #
    # NOTE: You should probably append to this rather than overwrite it.
    property excluded_exceptions : Array(Exception.class | String)

    # NOTE: DSN component - set automatically if DSN provided.
    property host : String?

    # Logger used by Raven. You can use any other `::Log`,
    # defaults to `Raven::Logger`.
    property logger : ::Log

    # Timeout waiting for the Sentry server connection to open in seconds.
    property connect_timeout : Time::Span = 1.second

    # NOTE: DSN component - set automatically if DSN provided.
    property path : String?

    # NOTE: DSN component - set automatically if DSN provided.
    property port : Int32?

    # Processors to run on data before sending upstream. See `DEFAULT_PROCESSORS`.
    # You should probably append to this rather than overwrite it.
    property processors : Array(Processor.class)

    # Project ID number to send to the Sentry server
    #
    # NOTE: If you provide a DSN, this will be set automatically.
    property project_id : UInt64?

    # Project directory root for revision detection. Could be Kemal root, etc.
    property project_root : String {
      if path = Process.executable_path
        File.dirname path
      else
        Dir.current
      end
    }

    # Public key for authentication with the Sentry server.
    #
    # NOTE: If you provide a DSN, this will be set automatically.
    property public_key : String?

    # Release tag to be passed with every event sent to Sentry.
    # We automatically try to set this to a git SHA or Capistrano release.
    property release : String?

    # The sampling factor to apply to events. A value of `0.0` will not send
    # any events, and a value of `1.0` will send 100% of events.
    property sample_rate : Float64 = 1.0

    # `Random` instance used when `sample_rate` is set.
    property random : Random { Random::DEFAULT }

    # Should sanitize values that look like credit card numbers?
    #
    # See `Processor::SanitizeData::CREDIT_CARD_PATTERN`.
    property? sanitize_credit_cards = true

    # By default, Sentry censors `Hash` values when their keys match things like
    # `"secret"`, `"password"`, etc. Provide an `Array` of `String`s that,
    # when matched in a hash key, will be censored and not sent to Sentry.
    #
    # See `Processor::SanitizeData::DEFAULT_FIELDS`.
    property sanitize_fields = [] of String | Regex

    # If you're sure you want to override the default sanitization values, you can
    # add to them to an array of `String`s here, e.g. `%w(authorization password)`.
    property sanitize_fields_excluded = [] of String | Regex

    # Sanitize additional HTTP headers - only `Authorization` is removed by default.
    #
    # See `Processor::HTTPHeaders::DEFAULT_FIELDS`.
    property sanitize_http_headers = [] of String | Regex

    # Request methods for which data should be removed.
    #
    # See `DEFAULT_REQUEST_METHODS_FOR_DATA_SANITIZATION`.
    property sanitize_data_for_request_methods : Array(String)

    # Can be one of `"http"`, `"https"`, or `"dummy"`.
    #
    # NOTE: DSN component - set automatically if DSN provided.
    property scheme : String?

    {% if flag?(:without_openssl) %}
      # SSL flag passed to `Raven::Client`.
      property ssl : Bool?
    {% else %}
      # SSL context passed to `Raven::Client`.
      property ssl : OpenSSL::SSL::Context::Client?
    {% end %}

    # Secret key for authentication with the Sentry server.
    #
    # DEPRECATED: This is deprecated and not necessary for newer Sentry
    # installations any more.
    #
    # NOTE: If you provide a DSN, this will be set automatically.
    property secret_key : String?

    # Include module versions in reports.
    property? send_modules = true

    # Simple server string - set this to the DSN found on your Sentry settings.
    getter dsn : String?

    # Hostname as an FQDN.
    property server_name : String?

    # Provide a configurable `Proc` callback to determine event capture.
    #
    # NOTE: Object passed into the block will be a `String` (messages)
    # or an `Exception`.
    #
    # ```
    # ->(obj : Exception | String) { obj.some_attr == false }
    # ```
    property should_capture : Proc(Exception | String, Bool)?

    # Silences ready message when `true`.
    property? silence_ready = false

    # Default tags for events.
    any_json_property :tags

    # Timeout when waiting for the server to return data.
    property read_timeout : Time::Span = 2.seconds

    # Optional `Proc`, called when the Sentry server cannot be contacted
    # for any reason.
    #
    # ```
    # ->(event : Raven::Event::HashType) {
    #   spawn { MyJobProcessor.send_email(event) }
    # }
    # ```
    property transport_failure_callback : Proc(Event::HashType, Nil)?

    # ditto
    def transport_failure_callback=(block : Event::HashType -> _)
      @transport_failure_callback = ->(event : Event::HashType) {
        block.call(event)
        nil
      }
    end

    # Optional `Proc`, called before sending an event to the server:
    #
    # ```
    # ->(event : Raven::Event, hint : Raven::Event::Hint?) {
    #   if hint.try(&.exception).try(&.message) =~ /database unavailable/i
    #     event.fingerprint << "database-unavailable"
    #   end
    #   event
    # }
    # ```
    def before_send=(block : Event, Event::Hint? -> _)
      @before_send = ->(event : Event, hint : Event::Hint?) {
        block.call(event, hint).as(Event?)
      }
    end

    # ditto
    def before_send(&block : Event, Event::Hint? -> _)
      self.before_send = block
    end

    # ditto
    property before_send : Proc(Event, Event::Hint?, Event?)?

    # Errors object - an `Array` containing error messages.
    getter errors = [] of String

    def initialize
      @current_environment = current_environment_from_env
      @exclude_loggers = [Logger::PROGNAME]
      @excluded_exceptions = IGNORE_DEFAULT.dup
      @logger = Logger.new(Log::IOBackend.new(STDOUT))
      @processors = DEFAULT_PROCESSORS.dup
      @sanitize_data_for_request_methods = DEFAULT_REQUEST_METHODS_FOR_DATA_SANITIZATION.dup
      @release = detect_release
      @server_name = server_name_from_env

      # try compile-time ENV variable
      {% if dsn = env("SENTRY_DSN") %}
        self.dsn = {{dsn}}
      {% else %}
        # try runtime ENV variable
        if dsn = ENV["SENTRY_DSN"]?
          self.dsn = dsn
        end
      {% end %}
    end

    def dsn=(uri : URI)
      uri_path = uri.path.try &.split('/')

      if uri.user
        # DSN-style string
        @public_key = uri.user
        @secret_key = uri.password
        @project_id = uri_path.try(&.pop?).try(&.to_u64)
      else
        @public_key = @secret_key = @project_id = nil
      end

      @scheme = uri.scheme
      @host = uri.host

      standard_ports = {"http": 80, "https": 443}
      @port = uri.port
      if scheme = @scheme
        @port = nil if @port == standard_ports[scheme]?
      end
      @path = uri_path.try &.join('/')
      @path = nil if @path.try &.empty?

      # For anyone who wants to read the base server string
      @dsn = String.build do |str|
        str << @scheme << "://"
        str << @public_key << '@' if @public_key
        str << @host
        str << ':' << @port if @port
        str << @path if @path
        str << '/' << @project_id if @project_id
      end
    end

    def dsn=(value : String)
      self.dsn = URI.parse(value)
    end

    def detect_release : String?
      detect_release_from_env ||
        detect_release_from_git ||
        detect_release_from_capistrano ||
        detect_release_from_heroku
    end

    private def running_on_heroku?
      File.directory?("/etc/heroku")
    end

    private HEROKU_DYNO_METADATA_MESSAGE =
      "You are running on Heroku but haven't enabled Dyno Metadata. " \
      "For Sentry's release detection to work correctly, please run " \
      "`heroku labs:enable runtime-dyno-metadata`"

    private def detect_release_from_heroku
      return unless running_on_heroku?
      return if ENV["CI"]?
      if commit = ENV["HEROKU_SLUG_COMMIT"]?
        return commit
      end
      logger.warn { HEROKU_DYNO_METADATA_MESSAGE }
      nil
    end

    private def detect_release_from_capistrano
      version = File.read(File.join(project_root, "REVISION")).strip rescue nil
      return version if version

      # Capistrano 3.0 - 3.1.x
      File.read_lines(File.join(project_root, "..", "revisions.log"))
        .last.strip.sub(/.*as release ([0-9]+).*/, "\1") rescue nil
    end

    private def detect_release_from_git
      Raven.sys_command_compiled("git rev-parse HEAD")
    end

    private def detect_release_from_env
      ENV["SENTRY_RELEASE"]?
    end

    private def heroku_dyno_name
      return unless running_on_heroku?
      ENV["DYNO"]?
    end

    # Try to resolve the hostname to an FQDN, but fall back to whatever
    # the load name is.
    private def resolve_hostname
      System.hostname
    end

    private def server_name_from_env
      heroku_dyno_name || resolve_hostname
    end

    private def current_environment_from_env
      ENV["SENTRY_ENVIRONMENT"]? || "default"
    end

    def capture_allowed?
      @errors = [] of String
      valid? &&
        capture_in_current_environment? &&
        sample_allowed?
    end

    def capture_allowed?(message_or_exc)
      @errors = [] of String
      capture_allowed? &&
        !raven_error?(message_or_exc) &&
        !excluded_exception?(message_or_exc) &&
        capture_allowed_by_callback?(message_or_exc)
    end

    private def capture_in_current_environment?
      return true if environments.empty? || environments.includes?(@current_environment)
      @errors << "Not configured to send/capture in environment '#{@current_environment}'"
      false
    end

    private def capture_allowed_by_callback?(message_or_exc)
      return true if !should_capture || should_capture.try &.call(message_or_exc)
      @errors << "#should_capture returned false"
      false
    end

    private def sample_allowed?
      return true if sample_rate == 1.0
      return true unless random.rand >= sample_rate
      @errors << "Excluded by random sample"
      false
    end

    def raven_error?(message_or_exc)
      return false unless message_or_exc.is_a?(Raven::Error)
      @errors << "Refusing to capture Raven error: #{message_or_exc.inspect}"
      true
    end

    def excluded_exception?(ex)
      return false unless ex.is_a?(Exception)
      return false unless excluded_exceptions.any? do |klass|
                            case klass
                            when Exception.class then klass >= ex.class
                            when String          then klass == ex.class.name
                            end
                          end
      @errors << "User excluded error: #{ex.inspect}"
      true
    end

    def valid?
      valid = true
      if dsn
        {% for key in REQUIRED_OPTIONS %}
          unless self.{{ key.id }}
            valid = false
            @errors << "No {{ key }} specified"
          end
        {% end %}
      else
        valid = false
        @errors << "DSN not set"
      end
      valid
    end

    def error_messages : String
      errors = @errors.map_with_index do |e, i|
        i > 0 ? e.downcase : e
      end
      errors.join(", ")
    end
  end
end

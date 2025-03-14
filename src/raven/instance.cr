module Raven
  # A copy of Raven's base module class methods, minus some of the integration
  # and global hooks since it's meant to be used explicitly. Useful for
  # sending errors to multiple sentry projects in a large application.
  #
  # ```
  # class Foo
  #   def initialize
  #     @other_raven = Raven::Instance.new
  #     @other_raven.configure do |config|
  #       config.dsn = "http://..."
  #     end
  #   end
  #
  #   def foo
  #     # ...
  #
  #
  #   rescue ex
  #     @other_raven.capture(ex)
  #   end
  # end
  # ```
  class Instance
    # See `Raven::Configuration`.
    property configuration : Configuration { Configuration.new }

    # The client object is responsible for delivering formatted data to the
    # Sentry server.
    property client : Client { Client.new(configuration) }

    @context : Context?
    @explicit_context : Context?

    def initialize(context = nil, config = nil)
      @context = @explicit_context = context
      @configuration = config
    end

    def context
      if @explicit_context
        @context ||= Context.new
      else
        Context.current
      end
    end

    # Tell the log that the client is good to go.
    def report_status
      return if configuration.silence_ready?
      if ex = configuration.capture_allowed!
        Log.info do
          "Raven #{VERSION} configured not to capture errors: #{ex.error_messages}"
        end
      else
        Log.info { "Raven #{VERSION} ready to catch errors" }
      end
    end

    # Call this method to modify defaults in your initializers.
    #
    # ```
    # Raven.configure do |config|
    #   config.dsn = "http://..."
    # end
    # ```
    def configure
      self.client = Client.new(configuration).tap { report_status }
    end

    # :ditto:
    def configure(&)
      yield configuration
      configure
    end

    # Sends User Feedback to Sentry server.
    #
    # *data* should be a `Hash(String, String)` with following keys:
    # - *name* (populated from `context.user[:username]` if left empty)
    # - *email* (populated from `context.user[:email]` if left empty)
    # - *comments*
    #
    # ```
    # Raven.send_feedback(Raven.last_event_id, {
    #   "name"     => "...",
    #   "email"    => "...",
    #   "comments" => "...",
    # })
    # ```
    #
    # NOTE: Sentry server records single (last) feedback for a given *event_id*.
    def send_feedback(event_id : String, data : Hash)
      if username = context.user[:username]?
        data["name"] ||= username.to_s
      end
      if email = context.user[:email]?
        data["email"] ||= email.to_s
      end
      client.send_feedback(event_id, data)
    end

    # Send an event to the configured Sentry server.
    #
    # ```
    # event = Raven::Event.new(message: "An error")
    # Raven.send_event(event)
    # ```
    def send_event(event, hint = nil)
      client.send_event(event, hint)
    end

    @last_event_id_mutex = Mutex.new
    @last_event_id : String?

    def last_event_id
      @last_event_id_mutex.synchronize do
        @last_event_id
      end
    end

    # Captures given `Exception` or `String` object and yields
    # created `Raven::Event` before sending to Sentry.
    #
    # ```
    # Raven.capture("boo!") do |event|
    #   event.extra.merge! foo: "bar"
    # end
    # ```
    def capture(obj : Exception | String, **options, &)
      if ex = configuration.capture_allowed!(obj)
        Log.debug do
          "'#{obj}' excluded from capture: #{ex.error_messages}"
        end
        return false
      end
      default_options = {
        configuration: configuration,
        context:       context,
      }
      options = default_options.merge(options)
      Event.from(obj, **options).tap do |event|
        hint =
          if obj.is_a?(String)
            Event::Hint.new(exception: nil, message: obj)
          else
            Event::Hint.new(exception: obj, message: nil)
          end
        yield event, hint
        if async = configuration.async
          begin
            async.call(event)
          rescue ex
            Log.error(exception: ex) { "Async event sending failed" }
            send_event(event, hint)
          end
        else
          send_event(event, hint)
        end
        @last_event_id_mutex.synchronize do
          @last_event_id = event.id
        end
        obj.as?(Exception)
          .try &.__raven_event_id = event.id
      end
    end

    # Captures given `Exception` or `String` object.
    #
    # ```
    # begin
    #   # ...
    # rescue ex
    #   Raven.capture ex
    # end
    #
    # Raven.capture "boo!"
    # ```
    def capture(obj : Exception | String, **options)
      capture(obj, **options) { }
    end

    # Captures an exception with given *klass*, *message*
    # and optional *backtrace*.
    #
    # ```
    # Raven.capture "FooBarError", "Foo got bar!"
    # ```
    #
    # NOTE: Useful in scenarios where you need to reconstruct the error
    # (usually along with a backtrace from external source), while
    # having no access to the actual Exception object.
    def capture(klass : String, message : String, backtrace : String? = nil, **options, &)
      formatted_message = "#{klass}: #{message}"
      capture(formatted_message, **options) do |event|
        ex = Interface::SingleException.new.tap do |iface|
          iface.module = klass.split("::")[0...-1].join("::")
          iface.type = klass
          iface.value = message

          if backtrace
            parsed = Backtracer.parse backtrace,
              configuration: configuration.backtracer

            iface.stacktrace = Interface::Stacktrace.new(backtrace: parsed).tap do |stacktrace|
              event.culprit = stacktrace.culprit
            end
          end
        end
        event.interface :exception, values: [ex]
        yield event
      end
    end

    # Capture and process any exceptions from the given block.
    #
    # ```
    # Raven.capture do
    #   MyApp.run
    # end
    # ```
    def capture(**options, &)
      yield
    rescue ex : Raven::Error
      raise ex # Don't capture Raven errors
    rescue ex : Exception
      capture(ex, **options)
      raise ex
    end

    # Provides extra context to the exception prior to it being handled by
    # Raven. An exception can have multiple annotations, which are merged
    # together.
    #
    # The options (annotation) is treated the same as the *options*
    # parameter to `capture` or `Event.from`, and
    # can contain the same `:user`, `:tags`, etc. options as these methods.
    #
    # These will be merged with the *options* parameter to
    # `Event.from` at the top of execution.
    #
    # ```
    # begin
    #   raise "Hello"
    # rescue ex
    #   Raven.annotate_exception(ex, user: {id: 1, email: "foo@example.com"})
    #   raise ex
    # end
    # ```
    def annotate_exception(ex : Exception, **options)
      {% for key in %i[user tags extra] %}
        if v = options[{{ key }}]?
          ex.__raven_{{ key.id }}.merge!(v)
        end
      {% end %}
      ex
    end

    # Returns `true` in case given *ex* was already captured,
    # `false` otherwise.
    #
    # ```
    # ex = Exception.new("boo!")
    #
    # Raven.captured_exception?(ex) # => false
    # Raven.capture(ex)
    # Raven.captured_exception?(ex) # => true
    # ```
    def captured_exception?(ex : Exception)
      !!ex.__raven_event_id
    end

    # Bind user context. Merges with existing context (if any).
    #
    # It is recommending that you send at least the `:id` and `:email`
    # values. All other values are arbitrary.
    #
    # ```
    # Raven.user_context(id: 1, email: "foo@example.com")
    # ```
    def user_context(hash = nil, **options)
      context.user.merge!(hash, options)
    end

    # Bind tags context. Merges with existing context (if any).
    #
    # Tags are key / value pairs which generally represent things like
    # application version, environment, role, and server names.
    #
    # ```
    # Raven.tags_context(my_custom_tag: "tag_value")
    # ```
    def tags_context(hash = nil, **options)
      context.tags.merge!(hash, options)
    end

    # Bind extra context. Merges with existing context (if any).
    #
    # Extra context shows up as *Additional Data* within Sentry,
    # and is completely arbitrary.
    #
    # ```
    # Raven.extra_context(my_custom_data: "value")
    # ```
    def extra_context(hash = nil, **options)
      context.extra.merge!(hash, options)
    end

    {% for key in %i[user extra tags] %}
      # Bind {{ key.id }} context.
      # Merges with existing context (if any).
      #
      # See `#{{ key.id }}_context`
      def {{ key.id }}_context(hash = nil, **options)
        prev_context = context.{{ key.id }}.clone
        begin
          context.{{ key.id }}.merge!(hash, options)
          yield
        ensure
          context.{{ key.id }} = prev_context
        end
        context.{{ key.id }}
      end
    {% end %}

    def breadcrumbs
      BreadcrumbBuffer.current
    end
  end
end

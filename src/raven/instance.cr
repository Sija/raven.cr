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
  #   rescue e
  #     @other_raven.capture(e)
  #   end
  # end
  # ```
  class Instance
    # See `Raven::Configuration`.
    property configuration : Configuration { Configuration.new }

    delegate logger, to: configuration

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
      if configuration.capture_allowed?
        logger.info "Raven #{VERSION} ready to catch errors"
      else
        logger.info "Raven #{VERSION} configured not to capture errors: #{configuration.error_messages}"
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
      self.client = Client.new(configuration)
      report_status
      client
    end

    # ditto
    def configure
      yield configuration
      configure
    end

    # Send an event to the configured Sentry server.
    #
    # ```
    # event = Raven::Event.new(message: "An error")
    # Raven.send_event(event)
    # ```
    def send_event(event)
      client.send_event(event)
    end

    # FIXME
    # @[ThreadLocal]
    @last_event_id : String?

    def last_event_id
      @last_event_id
    end

    # Captures given `Exception` or `String` object and yields
    # created `Raven::Event` before sending to Sentry.
    #
    # ```
    # Raven.capture("boo!") do |event|
    #   event.extra.merge! foo: "bar"
    # end
    # ```
    def capture(obj : Exception | String, **options, &block)
      unless configuration.capture_allowed?(obj)
        logger.debug "#{obj} excluded from capture: #{configuration.error_messages}"
        return false
      end
      if (event = Event.from(obj, configuration: configuration, context: context))
        event.initialize_with **options
        yield event
        if async = configuration.async
          begin
            async.call(event)
          rescue ex
            logger.error "Async event sending failed: #{ex.message}"
            send_event(event)
          end
        else
          send_event(event)
        end
        @last_event_id = event.id
        event
      end
    end

    # Captures given `Exception` or `String` object.
    #
    # ```
    # begin
    #   # ...
    # rescue e
    #   Raven.capture e
    # end
    #
    # Raven.capture "boo!"
    # ```
    def capture(obj : Exception | String, **options)
      capture(obj, **options) { }
    end

    # Capture and process any exceptions from the given block.
    #
    # ```
    # Raven.capture do
    #   MyApp.run
    # end
    # ```
    def capture(**options, &block)
      begin
        yield
      rescue e : Raven::Error
        raise e # Don't capture Raven errors
      rescue e : Exception
        capture(e, **options)
        raise e
      end
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
    def annotate_exception(exc, **options)
      exc.__raven_context.merge!(options)
      exc
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

    def breadcrumbs
      BreadcrumbBuffer.current
    end
  end
end

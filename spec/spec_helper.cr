require "spec"
require "log/spec"
require "../src/raven"

# Make sure we reset the env in case something leaks in
def with_clean_env(&)
  sentry_vars = ->{ ENV.to_h.select { |key, _| key.starts_with?("SENTRY_") } }
  previous_vars = sentry_vars.call
  begin
    previous_vars.each_key do |key|
      ENV.delete(key)
    end
    yield
  ensure
    extra_vars = sentry_vars.call
    extra_vars.each_key do |key|
      ENV.delete(key)
    end
    previous_vars.each do |key, value|
      ENV[key] = value
    end
  end
end

def build_exception
  Exception.new "Raven.cr test exception"
end

def build_exception_with_cause
  begin
    raise Exception.new "Exception A"
  rescue ex
    raise Exception.new "Exception B", ex
  end
rescue exception
  exception
end

def build_exception_with_two_causes
  begin
    begin
      raise Exception.new "Exception A"
    rescue ex
      raise Exception.new "Exception B", ex
    end
  rescue ex
    raise Exception.new "Exception C", ex
  end
rescue exception
  exception
end

def build_configuration
  Raven::Configuration.new.tap do |config|
    config.dsn = "dummy://12345:67890@sentry.localdomain:3000/sentry/42"
  end
end

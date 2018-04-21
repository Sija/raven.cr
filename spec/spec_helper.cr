require "spec"
require "../src/raven"

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

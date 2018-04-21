require "../../spec_helper"

def with_processor(klass : Raven::Processor.class)
  configuration = Raven::Configuration.new
  client = Raven::Client.new(configuration)
  processor = klass.new(client)

  yield processor, client, configuration
end

def build_processor(klass : Raven::Processor.class)
  with_processor(klass) { |processor| processor }
end

require "./spec_helper"

def stacktrace_from_event_hash(hash, index)
  ex_values = hash.to_any_json[:exception, :values].as(Array)
  ex_value = ex_values[index].as(Hash)
  ex_value[:stacktrace]?
end

describe Raven::Processor::RemoveStacktrace do
  processor = build_processor(Raven::Processor::RemoveStacktrace)

  it "should remove stacktraces" do
    data = Raven::Event.from(build_exception).to_hash

    stacktrace_from_event_hash(data, 0).should_not be_nil

    result = processor.process(data)
    result = result.to_any_json

    stacktrace_from_event_hash(result, 0).should be_nil
  end

  it "should remove stacktraces from causes" do
    data = Raven::Event.from(build_exception_with_cause).to_hash

    stacktrace_from_event_hash(data, 0).should_not be_nil
    stacktrace_from_event_hash(data, 1).should_not be_nil

    result = processor.process(data)
    result = result.to_any_json

    stacktrace_from_event_hash(result, 0).should be_nil
    stacktrace_from_event_hash(result, 1).should be_nil
  end

  it "should remove stacktraces from nested causes" do
    data = Raven::Event.from(build_exception_with_two_causes).to_hash

    stacktrace_from_event_hash(data, 0).should_not be_nil
    stacktrace_from_event_hash(data, 1).should_not be_nil
    stacktrace_from_event_hash(data, 2).should_not be_nil

    result = processor.process(data)
    result = result.to_any_json

    stacktrace_from_event_hash(result, 0).should be_nil
    stacktrace_from_event_hash(result, 1).should be_nil
    stacktrace_from_event_hash(result, 2).should be_nil
  end
end

require "../spec_helper"

describe Raven::Backtrace do
  backtrace = Raven::Backtrace.parse(caller)

  it "#lines" do
    backtrace.lines.should be_a(Array(Raven::Backtrace::Line))
  end

  it "#inspect" do
    backtrace.inspect.should match(/#<Backtrace: .*>$/)
  end

  it "#to_s" do
    backtrace.to_s.should match(/backtrace_spec.cr:4/)
  end

  it "#==" do
    backtrace2 = Raven::Backtrace.new(backtrace.lines)
    backtrace.should eq(backtrace2)
  end
end

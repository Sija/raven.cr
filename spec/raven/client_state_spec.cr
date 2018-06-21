require "../spec_helper"
require "timecop"

def with_client_state
  yield Raven::Client::State.new
end

describe Raven::Client::State do
  it "should try when online" do
    with_client_state do |state|
      state.should_try?.should be_true
    end
  end

  it "should not try with a new error" do
    with_client_state do |state|
      state.failure
      state.should_try?.should be_false
    end
  end

  it "should try again after time passes" do
    with_client_state do |state|
      Timecop.freeze(Time.now - 10.seconds) { state.failure }
      state.should_try?.should be_true
    end
  end

  it "should try again after success" do
    with_client_state do |state|
      state.failure
      state.success
      state.should_try?.should be_true
    end
  end

  it "should try again after retry_after" do
    with_client_state do |state|
      Timecop.freeze(Time.now - 2.seconds) { state.failure(1.second) }
      state.should_try?.should be_true
    end
  end

  it "should exponentially backoff" do
    with_client_state do |state|
      Timecop.freeze(Time.now) do
        state.failure
        Timecop.travel(Time.now + 2.seconds)
        state.should_try?.should be_true

        state.failure
        Timecop.travel(Time.now + 3.seconds)
        state.should_try?.should be_false
        Timecop.travel(Time.now + 2.seconds)
        state.should_try?.should be_true

        state.failure
        Timecop.travel(Time.now + 8.seconds)
        state.should_try?.should be_false
        Timecop.travel(Time.now + 2.seconds)
        state.should_try?.should be_true
      end
    end
  end
end

require "../spec_helper"

private class RandomSamplePass < Random::PCG32
  def rand
    0.74
  end
end

private class RandomSampleFail < Random::PCG32
  def rand
    0.76
  end
end

# Make sure we reset the env in case something leaks in
def with_clean_env
  sentry_vars = ->{ ENV.to_h.select { |key, _| key =~ /^(SENTRY_)|KEMAL_ENV/ } }
  previous_vars = sentry_vars.call
  begin
    previous_vars.each do |key, _|
      ENV.delete(key)
    end
    yield
  ensure
    extra_vars = sentry_vars.call
    extra_vars.each do |key, _|
      ENV.delete(key)
    end
    previous_vars.each do |key, value|
      ENV[key] = value
    end
  end
end

def with_configuration
  with_clean_env do
    yield Raven::Configuration.new
  end
end

def with_configuration_with_dsn
  with_configuration do |configuration|
    configuration.dsn = "http://12345:67890@sentry.localdomain:3000/sentry/42"
    yield configuration
  end
end

describe Raven::Configuration do
  it "should set some attributes when dsn is set" do
    with_configuration do |configuration|
      configuration.dsn = "http://12345:67890@sentry.localdomain:3000/sentry/42"

      configuration.project_id.should eq(42)
      configuration.public_key.should eq("12345")
      configuration.secret_key.should eq("67890")

      configuration.scheme.should eq("http")
      configuration.host.should eq("sentry.localdomain")
      configuration.port.should eq(3000)
      configuration.path.should eq("/sentry")

      configuration.dsn.should eq("http://12345@sentry.localdomain:3000/sentry/42")
    end
  end

  context "configuring for async" do
    it "should be configurable to send events async" do
      with_configuration do |configuration|
        called = false
        configuration.async = ->(_e : Raven::Event) { called = true }
        configuration.async.try &.call(Raven::Event.new)
        called.should be_true
      end
    end
  end

  context "being initialized with a current environment" do
    it "should send events if 'test' is whitelisted" do
      with_configuration_with_dsn do |configuration|
        configuration.current_environment = "test"

        configuration.environments = %w(test)
        configuration.capture_allowed?.should be_true
      end
    end

    it "should not send events if 'test' is not whitelisted" do
      with_configuration_with_dsn do |configuration|
        configuration.current_environment = "test"

        configuration.environments = %w(not_test)
        configuration.capture_allowed?.should be_false
        configuration.errors.should eq(["Not configured to send/capture in environment 'test'"])
      end
    end
  end

  context "being initialized without a current environment" do
    it "defaults to 'default'" do
      with_configuration do |configuration|
        configuration.current_environment.should eq("default")
      end
    end

    it "uses `SENTRY_CURRENT_ENV` env variable" do
      with_clean_env do
        ENV["SENTRY_CURRENT_ENV"] = "set-with-sentry-current-env"
        ENV["KEMAL_ENV"] = "set-with-kemal-env"

        configuration = Raven::Configuration.new
        configuration.current_environment.should eq("set-with-sentry-current-env")
      end
    end

    it "uses `KEMAL_ENV` env variable" do
      with_clean_env do
        ENV["SENTRY_CURRENT_ENV"] = nil
        ENV["KEMAL_ENV"] = "set-with-kemal-env"

        configuration = Raven::Configuration.new
        configuration.current_environment.should eq("set-with-kemal-env")
      end
    end
  end

  context "with a should_capture callback configured" do
    it "should not send events if #should_capture returns false" do
      with_configuration_with_dsn do |configuration|
        configuration.should_capture = ->(obj : Exception | String) { obj != "don't send me" }

        configuration.capture_allowed?("don't send me").should be_false
        configuration.errors.should eq(["#should_capture returned false"])
        configuration.capture_allowed?("send me").should be_true
      end
    end
  end

  context "with an invalid server" do
    it "#captured_allowed? returns false" do
      with_configuration do |configuration|
        configuration.dsn = "dummy://trololo"

        configuration.capture_allowed?.should be_false
        configuration.errors.should eq([
          "No :public_key specified",
          "No :project_id specified",
        ])
      end
    end
  end

  context "with a sample rate" do
    it "#captured_allowed? returns false when sampled" do
      with_configuration_with_dsn do |configuration|
        configuration.sample_rate = 0.75
        configuration.random = RandomSampleFail.new

        configuration.capture_allowed?.should be_false
        configuration.errors.should eq(["Excluded by random sample"])
      end
    end

    it "#captured_allowed? returns true when not sampled" do
      with_configuration_with_dsn do |configuration|
        configuration.sample_rate = 0.75
        configuration.random = RandomSamplePass.new

        configuration.capture_allowed?.should be_true
      end
    end
  end
end

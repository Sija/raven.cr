require "./spec_helper"

private class SanitizeDataTest < Raven::Processor::SanitizeData
  def fields_pattern
    super
  end
end

describe Raven::Processor::SanitizeData do
  processor = build_processor(Raven::Processor::SanitizeData)

  context "configuration for sanitize fields" do
    it "should union default sanitize fields with user-defined sanitize fields" do
      with_processor(SanitizeDataTest) do |processor|
        processor.sanitize_fields = Raven::Processor::SanitizeData::DEFAULT_FIELDS | %w(test monkeybutt)

        expected_fields_pattern = /authorization|password|password_repeat|passwd|secret|ssn|(?i-msx:social(.*)?sec)|(?-imsx:\btest\b)|(?-imsx:\bmonkeybutt\b)/

        processor.fields_pattern.should eq(expected_fields_pattern)
      end
    end

    it "should remove default fields if specified by sanitize_fields_excluded" do
      with_processor(SanitizeDataTest) do |processor|
        processor.sanitize_fields_excluded.clear
        processor.sanitize_fields_excluded << "authorization"

        expected_fields_pattern = /password|password_repeat|passwd|secret|ssn|(?i-msx:social(.*)?sec)/

        processor.fields_pattern.should eq(expected_fields_pattern)
      end
    end

    it "accepts regexes" do
      with_processor(SanitizeDataTest) do |processor|
        processor.sanitize_fields.clear
        processor.sanitize_fields << /foo(.*)?bar/

        expected_fields_pattern = /authorization|password|password_repeat|passwd|secret|ssn|(?i-msx:social(.*)?sec)|(?-imsx:foo(.*)?bar)/

        processor.fields_pattern.should eq(expected_fields_pattern)
      end
    end
  end

  it "should filter http data" do
    with_processor(Raven::Processor::SanitizeData) do |processor|
      processor.sanitize_fields.clear
      processor.sanitize_fields << "user_field"

      data = {
        "sentry.interfaces.Http" => {
          "data" => {
            "foo"                    => "bar",
            "password"               => "hello",
            "the_secret"             => "hello",
            "a_password_here"        => "hello",
            "mypasswd"               => "hello",
            "test"                   => 1,
            :ssn                     => "123-45-6789", # test symbol handling
            "social_security_number" => 123_456_789,
            "user_field"             => "user",
            "user_field_foo"         => "hello",
            "query_string"           => "foo=bar%E9", # test utf8 handling
          },
        },
      }

      result = processor.process(data)
      result = result.to_any_json

      vars = result["sentry.interfaces.Http", "data"].as(Hash)
      vars["foo"].should eq("bar")
      vars["password"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["the_secret"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["a_password_here"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["mypasswd"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["test"].should eq(1)
      vars[:ssn].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["social_security_number"].should eq(Raven::Processor::SanitizeData::INT_MASK)
      vars["user_field"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["user_field_foo"].should eq("hello")
      vars["query_string"].should eq("foo=bar")
    end
  end

  it "should filter json data" do
    with_processor(Raven::Processor::SanitizeData) do |processor|
      processor.sanitize_fields.clear
      processor.sanitize_fields << "user_field"

      data_with_json = {
        "json" => {
          "foo"                    => "bar",
          "password"               => "hello",
          "the_secret"             => "hello",
          "a_password_here"        => "hello",
          "mypasswd"               => "hello",
          "test"                   => 1,
          "ssn"                    => "123-45-6789",
          "social_security_number" => 123_456_789,
          "user_field"             => "user",
          "user_field_foo"         => "hello",
        }.to_json,
      }

      result = processor.process(data_with_json)
      result = JSON.parse(result["json"].as(String))

      vars = result
      vars["foo"].should eq("bar")
      vars["password"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["the_secret"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["a_password_here"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["mypasswd"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["test"].should eq(1)
      vars["ssn"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["social_security_number"].should eq(Raven::Processor::SanitizeData::INT_MASK)
      vars["user_field"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
      vars["user_field_foo"].should eq("hello")
    end
  end

  it "should filter json embedded inside of a Hash" do
    data_with_embedded_json = {
      "data" => {
        "json"      => %w(foo bar).to_json,
        "json_hash" => {"foo" => "bar"}.to_json,
        "sensitive" => {"password" => "secret"}.to_json,
      },
    }

    result = processor.process(data_with_embedded_json)
    result = result.to_any_json

    JSON.parse(result["data", "json"].as(String)).should eq(%w(foo bar))
    JSON.parse(result["data", "json_hash"].as(String)).should eq({"foo" => "bar"})
    JSON.parse(result["data", "sensitive"].as(String)).should eq({"password" => Raven::Processor::SanitizeData::STRING_MASK})
  end

  it "should not fail when json is invalid" do
    data_with_invalid_json = {
      "data" => {
        "invalid" => "{\r\n\"key\":\"value\",\r\n \"foo\":{\"bar\":\"baz\"}\r\n",
      },
    }

    result = processor.process(data_with_invalid_json)
    result = result.to_any_json

    expect_raises(JSON::ParseException) do
      JSON.parse(result["data", "invalid"].as(String))
    end
  end

  it "should filter credit card values" do
    data = {
      "ccnumba"     => "4242424242424242",
      "ccnumba_int" => 4242424242424242,
    }

    result = processor.process(data)

    result["ccnumba"].should eq(Raven::Processor::SanitizeData::STRING_MASK)
    result["ccnumba_int"].should eq(Raven::Processor::SanitizeData::INT_MASK)
  end

  it "should pass through credit card values if configured" do
    with_processor(Raven::Processor::SanitizeData) do |processor|
      processor.sanitize_credit_cards = false

      data = {
        "ccnumba"     => "4242424242424242",
        "ccnumba_int" => 4242424242424242,
      }

      result = processor.process(data)
      result["ccnumba"].should eq("4242424242424242")
      result["ccnumba_int"].should eq(4242424242424242)
    end
  end

  pending "sanitizes hashes nested in arrays" do
    data = {
      "empty_array" => [] of String,
      "array"       => [{"password" => "secret"}],
    }

    result = processor.process(data)

    result["array"].should eq([{"password" => Raven::Processor::SanitizeData::STRING_MASK}])
  end

  context "query strings" do
    it "sanitizes" do
      data = {
        "sentry.interfaces.Http" => {
          "data" => {
            "query_string" => "foo=bar&password=secret",
          },
        },
      }

      result = processor.process(data)
      result = result.to_any_json

      result["sentry.interfaces.Http", "data", "query_string"].as(String).should_not contain("secret")
    end

    it "handles :query_string as symbol" do
      data = {
        "sentry.interfaces.Http" => {
          "data" => {
            :query_string => "foo=bar&password=secret",
          },
        },
      }

      result = processor.process(data)
      result = result.to_any_json

      result["sentry.interfaces.Http", "data", :query_string].as(String).should_not contain("secret")
    end

    pending "handles multiple values for a key" do
      data = {
        "sentry.interfaces.Http" => {
          "data" => {
            "query_string" => "foo=bar&foo=fubar&foo=barfoo",
          },
        },
      }

      result = processor.process(data)
      result = result.to_any_json

      query_string = result["sentry.interfaces.Http", "data", "query_string"].as(String).split('&')
      query_string.should contain("foo=bar")
      query_string.should contain("foo=fubar")
      query_string.should contain("foo=barfoo")
    end

    it "handles url encoded keys and values" do
      encoded_query_string = "Bio%204%24=cA%24%7C-%7C+M%28%29n3%5E"
      data = {
        "sentry.interfaces.Http" => {
          "data" => {
            "query_string" => encoded_query_string,
          },
        },
      }

      result = processor.process(data)
      result = result.to_any_json

      result["sentry.interfaces.Http", "data", "query_string"].should eq(encoded_query_string)
    end
  end

  # Sometimes this sort of thing can show up in request headers,
  # e.g. X-REQUEST-START on Heroku
  it "does not censor milliseconds since the epoch" do
    data = {
      :millis_since_epoch => "1507671610403",
    }

    result = processor.process(data)

    result.should eq({:millis_since_epoch => "1507671610403"})
  end
end

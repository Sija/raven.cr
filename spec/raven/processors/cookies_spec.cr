require "./spec_helper"

describe Raven::Processor::Cookies do
  processor = build_processor(Raven::Processor::Cookies)

  it "should remove cookies" do
    test_data = {
      :request => {
        :headers => {
          "Cookie"         => "_sentry-testapp_session=SlRKVnNha2Z",
          "Another-Header" => "still-here",
        },
        :cookies         => "_sentry-testapp_session=SlRKVnNha2Z",
        :some_other_data => "still-here",
      },
    }

    result = processor.process(test_data)
    result = result.to_any_json

    result[:request, :cookies].should eq("********")
    result[:request, :headers, "Cookie"].should eq("********")
    result[:request, :some_other_data].should eq("still-here")
    result[:request, :headers, "Another-Header"].should eq("still-here")
  end
end

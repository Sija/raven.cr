require "./spec_helper"

describe Raven::Processor::HTTPHeaders do
  it "should remove HTTP headers we don't like" do
    with_processor(Raven::Processor::HTTPHeaders) do |processor|
      data = {
        :request => {
          :headers => {
            "Authorization"  => "dontseeme",
            "Another-Header" => "still-here",
          },
        },
      }

      result = processor.process(data)
      result = result.to_any_json

      result[:request, :headers, "Authorization"].should eq("********")
      result[:request, :headers, "Another-Header"].should eq("still-here")
    end
  end

  it "should be configurable" do
    with_processor(Raven::Processor::HTTPHeaders) do |processor|
      processor.sanitize_http_headers << "User-Defined-Header"

      data = {
        :request => {
          :headers => {
            "User-Defined-Header" => "dontseeme",
            "Another-Header"      => "still-here",
          },
        },
      }

      result = processor.process(data)
      result = result.to_any_json

      result[:request, :headers, "User-Defined-Header"].should eq("********")
      result[:request, :headers, "Another-Header"].should eq("still-here")
    end
  end
end

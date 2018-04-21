require "./spec_helper"

TESTED_METHODS        = %w(GET POST PUT PATCH)
TESTED_CONFIGURATIONS = {
  %w(POST PUT PATCH),
  %w(POST),
  %w(PUT),
  %w(PATCH),
  %w(POST PUT),
  %w(PUT PATCH),
  %w(POST PATCH),
  %w(),
}

def test_data_with_method(method)
  {
    :request => {
      :method => method,
      :data   => {
        "sensitive_stuff" => "TOP_SECRET-GAMMA",
      },
    },
  }
end

describe Raven::Processor::RequestMethodData do
  TESTED_CONFIGURATIONS.each do |sanitized_methods|
    processor = build_processor(Raven::Processor::RequestMethodData)
    processor.request_methods = sanitized_methods

    context "with methods: #{sanitized_methods.join ", "}" do
      context "sanitized methods: #{sanitized_methods.join ", "}" do
        sanitized_methods.each do |sanitized_method|
          it "sanitizes the data for #{sanitized_method}" do
            test_data = test_data_with_method(sanitized_method)

            result = processor.process(test_data)
            result = result.to_any_json

            result[:request, :data].should eq("********")
          end
        end
      end

      unsanitized_methods = TESTED_METHODS - sanitized_methods
      context "unsanitized methods: #{unsanitized_methods.join ", "}" do
        unsanitized_methods.each do |unsanitized_method|
          it "does not sanitizes the data for #{unsanitized_method}" do
            test_data = test_data_with_method(unsanitized_method)

            result = processor.process(test_data)
            result = result.to_any_json

            result[:request, :data].should eq({
              "sensitive_stuff" => "TOP_SECRET-GAMMA",
            })
          end
        end
      end
    end
  end
end

require "./spec_helper"

describe Raven::Processor::RemoveCircularReferences do
  processor = build_processor(Raven::Processor::RemoveCircularReferences)

  it "should cleanup circular references" do
    test_data = AnyHash::JSON.new
    test_data["data"] = test_data
    test_data["leave intact"] = {"not a circular reference" => true}

    result = processor.process(test_data.to_h)
    result = result.as(Hash(AnyHash::JSONTypes::Key, AnyHash::JSONTypes::Value))
    result = result.to_any_json

    result["data"].should eq("(...)")
    result["leave intact"].should eq({"not a circular reference" => true})
  end
end

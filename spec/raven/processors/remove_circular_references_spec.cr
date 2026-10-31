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

  it "should leave intact values referenced multiple times" do
    shared_hash = {"foo" => "bar"}.to_any_json.to_h
    shared_array = [1, 2] of AnyHash::JSONTypes::Value

    test_data = AnyHash::JSON.new
    test_data["a"] = shared_hash
    test_data["b"] = shared_hash
    test_data["c"] = shared_array
    test_data["d"] = shared_array

    result = processor.process(test_data.to_h)
    result = result.as(Hash(AnyHash::JSONTypes::Key, AnyHash::JSONTypes::Value))
    result = result.to_any_json

    result["a"].should eq({"foo" => "bar"})
    result["b"].should eq({"foo" => "bar"})
    result["c"].should eq([1, 2])
    result["d"].should eq([1, 2])
  end
end

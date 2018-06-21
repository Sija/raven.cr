require "./spec_helper"

describe Raven::Processor::UTF8Conversion do
  invalid_utf8_string = "Invalid utf8 string goes here\255"
  processor = build_processor(Raven::Processor::UTF8Conversion)

  it "has a utf8 fixture which is not valid utf-8" do
    invalid_utf8_string.valid_encoding?.should be_false
    expect_raises(ArgumentError, "Invalid multibyte sequence") do
      invalid_utf8_string.encode("UTF-8")
    end
  end

  it "should cleanup invalid UTF-8 bytes" do
    data = {"invalid" => invalid_utf8_string}

    results = processor.process(data)
    results["invalid"].should eq("Invalid utf8 string goes here")
  end

  it "should cleanup invalid UTF-8 bytes in Exception messages" do
    ex = Exception.new(invalid_utf8_string)

    results = processor.process(ex)
    results.message.should eq("Invalid utf8 string goes here")
  end

  it "should retain #cause and #callstack in cleaned up Exception" do
    ex = Exception.new(nil, Exception.new)
    ex.callstack = CallStack.new

    results = processor.process(ex)
    results.cause.should eq(ex.cause)
    results.callstack.should eq(ex.callstack)
  end

  it "should keep valid UTF-8 bytes after cleaning" do
    data = {"invalid" => "한국, 中國, 日本(にっぽん)\255"}

    results = processor.process(data)
    results["invalid"].should eq("한국, 中國, 日本(にっぽん)")
  end

  it "should work recursively on hashes" do
    data = {"nested" => {"invalid" => invalid_utf8_string}}

    results = processor.process(data)
    results["nested"]["invalid"].should eq("Invalid utf8 string goes here")
  end

  it "should work recursively on arrays" do
    data = ["good string", "good string",
            ["good string", invalid_utf8_string]]

    results = processor.process(data)
    results[2][1].should eq("Invalid utf8 string goes here")
  end

  it "should not blow up on symbols" do
    data = {:key => :value}

    results = processor.process(data)
    results[:key].should eq(:value)
  end
end

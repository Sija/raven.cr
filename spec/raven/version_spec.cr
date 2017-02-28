require "yaml"
require "../spec_helper"

describe Raven::VERSION do
  it "should have proper format" do
    Raven::VERSION.should match /^\d+(\.\d+){2,3}(-\w+)?$/
  end

  it "should match shard.yml" do
    version = YAML.parse(File.read(File.join(__DIR__, "../..", "shard.yml")))["version"].as_s
    version.should eq Raven::VERSION
  end
end

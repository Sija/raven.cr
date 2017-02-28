require "./spec_helper"

describe Raven do
  context ".instance" do
    it "is set" do
      Raven.instance.should be_a(Raven::Instance)
    end
  end
end

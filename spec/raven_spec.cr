require "./spec_helper"

describe Raven do
  context ".sys_command" do
    it "should execute system commands" do
      Raven.sys_command("echo 'Sentry'").should eq("Sentry")
    end

    it "should return nil if a system command doesn't exist" do
      Raven.sys_command("asdasdasdsa").should be_nil
    end

    it "should return nil if the process exits with a non-zero exit status" do
      Raven.sys_command("uname -c").should be_nil # non-existent uname option
    end
  end
end

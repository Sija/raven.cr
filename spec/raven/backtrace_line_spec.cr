require "../spec_helper"

def with_line(path = "#{__DIR__}/foo.cr", method = "foo_bar?")
  line = "#{path}:1:7 in '#{method}'"
  yield Raven::Backtrace::Line.parse(line)
end

describe Raven::Backtrace::Line do
  describe ".parse" do
    it "fails to parse an empty string" do
      expect_raises(ArgumentError) { Raven::Backtrace::Line.parse("") }
    end

    context "when --no-debug flag is set" do
      it "parses line with any value as method" do
        backtrace_line = "__crystal_main"
        line = Raven::Backtrace::Line.parse(backtrace_line)

        line.number.should be_nil
        line.column.should be_nil
        line.method.should eq(backtrace_line)
        line.file.should be_nil
        line.relative_path.should be_nil
        line.under_src_path?.should be_false
        line.shard_name.should be_nil
        line.in_app?.should be_false
      end
    end

    context "with ~proc signature" do
      it "parses absolute path outside of src/ dir" do
        backtrace_line = "~proc2Proc(Fiber, (IO::FileDescriptor | Nil))@/usr/local/Cellar/crystal/0.27.2/src/fiber.cr:72"
        line = Raven::Backtrace::Line.parse(backtrace_line)

        line.number.should eq(72)
        line.column.should be_nil
        line.method.should eq("~proc2Proc(Fiber, (IO::FileDescriptor | Nil))")
        line.file.should eq("/usr/local/Cellar/crystal/0.27.2/src/fiber.cr")
        line.relative_path.should be_nil
        line.under_src_path?.should be_false
        line.shard_name.should be_nil
        line.in_app?.should be_false
      end

      it "parses relative path inside of lib/ dir" do
        backtrace_line = "~procProc(HTTP::Server::Context, String)@lib/kemal/src/kemal/route.cr:11"
        line = Raven::Backtrace::Line.parse(backtrace_line)

        line.number.should eq(11)
        line.column.should be_nil
        line.method.should eq("~procProc(HTTP::Server::Context, String)")
        line.file.should eq("lib/kemal/src/kemal/route.cr")
        line.relative_path.should eq("lib/kemal/src/kemal/route.cr")
        line.under_src_path?.should be_false
        line.shard_name.should eq("kemal")
        line.in_app?.should be_false
      end
    end

    it "parses absolute path outside of configuration.src_path" do
      path = "/some/absolute/path/to/foo.cr"
      with_line(path: path) do |line|
        line.number.should eq(1)
        line.column.should eq(7)
        line.method.should eq("foo_bar?")
        line.file.should eq(path)
        line.relative_path.should be_nil
        line.under_src_path?.should be_false
        line.shard_name.should be_nil
        line.in_app?.should be_false
      end
    end

    context "with in_app? = false" do
      it "parses absolute path outside of src/ dir" do
        with_line do |line|
          line.number.should eq(1)
          line.column.should eq(7)
          line.method.should eq("foo_bar?")
          line.file.should eq("#{__DIR__}/foo.cr")
          line.relative_path.should eq("spec/raven/foo.cr")
          line.under_src_path?.should be_true
          line.shard_name.should be_nil
          line.in_app?.should be_false
        end
      end

      it "parses relative path outside of src/ dir" do
        path = "some/relative/path/to/foo.cr"
        with_line(path: path) do |line|
          line.number.should eq(1)
          line.column.should eq(7)
          line.method.should eq("foo_bar?")
          line.file.should eq(path)
          line.relative_path.should eq(path)
          line.under_src_path?.should be_false
          line.shard_name.should be_nil
          line.in_app?.should be_false
        end
      end
    end

    context "with in_app? = true" do
      it "parses absolute path inside of src/ dir" do
        src_path = File.expand_path("../../src", __DIR__)
        path = "#{src_path}/foo.cr"
        with_line(path: path) do |line|
          line.number.should eq(1)
          line.column.should eq(7)
          line.method.should eq("foo_bar?")
          line.file.should eq(path)
          line.relative_path.should eq("src/foo.cr")
          line.under_src_path?.should be_true
          line.shard_name.should be_nil
          line.in_app?.should be_true
        end
      end

      it "parses relative path inside of src/ dir" do
        path = "src/foo.cr"
        with_line(path: path) do |line|
          line.number.should eq(1)
          line.column.should eq(7)
          line.method.should eq("foo_bar?")
          line.file.should eq(path)
          line.relative_path.should eq(path)
          line.under_src_path?.should be_false
          line.shard_name.should be_nil
          line.in_app?.should be_true
        end
      end
    end

    context "with shard path" do
      it "parses absolute path inside of lib/ dir" do
        lib_path = File.expand_path("../../lib/bar", __DIR__)
        path = "#{lib_path}/src/bar.cr"
        with_line(path: path) do |line|
          line.number.should eq(1)
          line.column.should eq(7)
          line.method.should eq("foo_bar?")
          line.file.should eq(path)
          line.relative_path.should eq("lib/bar/src/bar.cr")
          line.under_src_path?.should be_true
          line.shard_name.should eq "bar"
          line.in_app?.should be_false
        end
      end

      it "parses relative path inside of lib/ dir" do
        path = "lib/bar/src/bar.cr"
        with_line(path: path) do |line|
          line.number.should eq(1)
          line.column.should eq(7)
          line.method.should eq("foo_bar?")
          line.file.should eq(path)
          line.relative_path.should eq(path)
          line.under_src_path?.should be_false
          line.shard_name.should eq "bar"
          line.in_app?.should be_false
        end
      end
    end
  end

  it "#inspect" do
    with_line do |line|
      line.inspect.should match(/Backtrace::Line(.*)$/)
    end
  end

  it "#to_s" do
    with_line do |line|
      line.to_s.should eq "`foo_bar?` at #{__DIR__}/foo.cr:1:7"
    end
  end

  it "#==" do
    with_line do |line|
      with_line do |line2|
        line.should eq(line2)
      end
      with_line(method: "other_method") do |line2|
        line.should_not eq(line2)
      end
    end
  end
end

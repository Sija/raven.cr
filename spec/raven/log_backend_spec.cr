require "log"
require "colorize"

private def build_logger(source = nil, **opts)
  opts = {
    record_breadcrumbs: false,
    capture_exceptions: false,
    capture_all:        false,
  }.merge(opts)

  backend = Raven::LogBackend.new(**opts)

  Log::Builder.new
    .tap(&.bind("*", :trace, backend))
    .for(source.to_s)
end

private def with_clean_configuration
  prev_configuration = Raven.instance.configuration.dup
  begin
    Raven.instance.configuration = build_configuration
    yield
  ensure
    Raven.instance.configuration = prev_configuration
  end
end

describe Raven::LogBackend do
  around_each do |example|
    Raven::BreadcrumbBuffer.clear!
    with_clean_configuration do
      Raven.configuration.exclude_loggers.clear
      example.run
    end
    Raven::BreadcrumbBuffer.clear!
  end

  context ":record_breadcrumbs" do
    it "respects Raven.configuration.exclude_loggers setting" do
      Raven.configuration.exclude_loggers = %w[spec.raven.*]

      logger = build_logger("spec.raven.crumbs", record_breadcrumbs: true)
      logger.trace { "foo" }

      logger = build_logger("spec.raven", record_breadcrumbs: true)
      logger.trace { "bar" }

      Raven.breadcrumbs.should be_empty
    end

    context "with exception" do
      it "records entries as breadcrumbs (true)" do
        ex = build_exception

        logger = build_logger("spec.raven", record_breadcrumbs: true)
        logger.trace(exception: ex) { "foo".colorize(:green) }

        crumbs = Raven.breadcrumbs
        crumbs.size.should eq(1)

        last = crumbs.peek.should_not be_nil
        last.level.should eq(Raven::Breadcrumb::Severity::DEBUG)
        last.category.should eq("spec.raven")
        last.message.should eq("foo -- (%s): %s" % {ex.class, ex.message})
      end
    end

    context "without exception" do
      it "records entries as breadcrumbs (true)" do
        logger = build_logger("spec.raven", record_breadcrumbs: true)
        logger.trace { "foo".colorize(:green) }

        crumbs = Raven.breadcrumbs
        crumbs.size.should eq(1)

        last = crumbs.peek.should_not be_nil
        last.level.should eq(Raven::Breadcrumb::Severity::DEBUG)
        last.category.should eq("spec.raven")
        last.message.should eq("foo")
      end
    end

    it "records entries as breadcrumbs (false)" do
      logger = build_logger(record_breadcrumbs: false)
      logger.trace { "boo!" }

      Raven.breadcrumbs.should be_empty
    end
  end

  context ":capture_exceptions" do
    it "captures attached exception if present (true)" do
      ex = build_exception

      logger = build_logger(capture_exceptions: true)
      logger.trace(exception: ex) { "boo!" }

      Raven.captured_exception?(ex).should be_true
    end

    it "captures attached exception if present (false)" do
      ex = build_exception

      logger = build_logger(capture_exceptions: false)
      logger.trace(exception: ex) { "boo!" }

      Raven.captured_exception?(ex).should be_false
    end
  end

  context ":capture_all" do
    it "captures attached exception if present (true)" do
      ex = build_exception

      logger = build_logger(capture_all: true)
      logger.trace(exception: ex) { "boo!" }

      Raven.captured_exception?(ex).should be_true
    end

    it "captures attached exception if present (false)" do
      ex = build_exception

      logger = build_logger(capture_all: false)
      logger.trace(exception: ex) { "boo!" }

      Raven.captured_exception?(ex).should be_false
    end

    it "captures every entry (true)" do
      prev_event_id = Raven.last_event_id

      logger = build_logger(capture_all: true)
      logger.trace { "boo!" }

      Raven.last_event_id.should_not eq(prev_event_id)
    end

    it "captures every entry (false)" do
      prev_event_id = Raven.last_event_id

      logger = build_logger(capture_all: false)
      logger.trace { "boo!" }

      Raven.last_event_id.should eq(prev_event_id)
    end
  end
end

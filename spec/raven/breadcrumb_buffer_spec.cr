require "../spec_helper"

def with_breadcrumb_buffer
  breadcrumbs = Raven::BreadcrumbBuffer.new(10)
  yield breadcrumbs
end

describe Raven::BreadcrumbBuffer do
  it "records breadcrumbs w/a block" do
    with_breadcrumb_buffer do |breadcrumbs|
      breadcrumbs.empty?.should be_true

      crumb = nil
      breadcrumbs.record do |b|
        b.message = "test"
        crumb = b
      end

      breadcrumbs.empty?.should be_false
      breadcrumbs.members.size.should eq(1)
      breadcrumbs.members.first.should eq(crumb)
    end
  end

  it "records breadcrumbs w/o block" do
    with_breadcrumb_buffer do |breadcrumbs|
      crumb = Raven::Breadcrumb.new.tap { |b| b.message = "test" }
      breadcrumbs.record(crumb)

      breadcrumbs.members.first.should eq(crumb)
    end
  end

  it "allows peeking" do
    with_breadcrumb_buffer do |breadcrumbs|
      breadcrumbs.peek.should be_nil

      crumb = Raven::Breadcrumb.new.tap { |b| b.message = "test" }
      breadcrumbs.record(crumb)

      breadcrumbs.peek.should eq(crumb)
    end
  end

  it "is enumerable" do
    with_breadcrumb_buffer do |breadcrumbs|
      breadcrumbs.should be_a Enumerable(Raven::Breadcrumb)
    end
  end

  it "evicts when buffer exceeded" do
    with_breadcrumb_buffer do |breadcrumbs|
      (0..30).each do |i|
        breadcrumbs.record(Raven::Breadcrumb.new.tap { |b| b.message = i.to_s })
      end

      breadcrumbs.members.first.message.should eq("21")
      breadcrumbs.members.last.message.should eq("30")
    end
  end

  it "converts to a hash" do
    with_breadcrumb_buffer do |breadcrumbs|
      breadcrumbs.peek.should be_nil

      crumb = Raven::Breadcrumb.new.tap { |b| b.message = "test" }
      breadcrumbs.record(crumb)

      breadcrumbs.to_hash["values"].should eq([crumb.to_hash])
    end
  end

  it "clears in a threaded context" do
    crumb = Raven::Breadcrumb.new.tap { |b| b.message = "test" }
    Raven::BreadcrumbBuffer.current.record(crumb)

    Raven::BreadcrumbBuffer.clear!
    Raven::BreadcrumbBuffer.current.empty?.should be_true
  end
end

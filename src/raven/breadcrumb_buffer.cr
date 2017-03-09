module Raven
  class BreadcrumbBuffer
    include Enumerable(Breadcrumb)

    # FIXME
    # @[ThreadLocal]
    @@current : self?

    def self.current
      @@current ||= new
    end

    def self.clear!
      @@current = nil
    end

    getter buffer : Array(Breadcrumb?)

    def initialize(size = 100)
      @buffer = Array(Breadcrumb?).new(size, nil)
    end

    def record(crumb : Breadcrumb) : Void
      @buffer.shift
      @buffer << crumb
    end

    def record(crumb : Breadcrumb? = nil) : Void
      crumb ||= Breadcrumb.new
      yield crumb
      self.record crumb
    end

    def members : Array(Breadcrumb)
      @buffer.compact
    end

    def peek
      members.last?
    end

    def each
      members.each do |breadcrumb|
        yield breadcrumb
      end
    end

    def empty?
      !members.any?
    end

    def to_hash
      {
        "values" => members.map(&.to_hash),
      }
    end
  end
end

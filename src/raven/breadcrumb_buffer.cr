module Raven
  class BreadcrumbBuffer
    include Enumerable(Breadcrumb)

    @@mutex = Mutex.new
    @@current : self?

    def self.current
      @@mutex.synchronize do
        @@current ||= new
      end
    end

    def self.clear!
      @@mutex.synchronize do
        @@current = nil
      end
    end

    getter buffer : Array(Breadcrumb?)

    def initialize(size = 100)
      @buffer = Array(Breadcrumb?).new(size, nil)
    end

    def record(crumb : Breadcrumb) : Nil
      @buffer.shift
      @buffer << crumb
    end

    def record(**opts, &) : Nil
      crumb = Breadcrumb.new(**opts)
      yield crumb
      record crumb
    end

    def record(**opts) : Nil
      record(**opts) { }
    end

    def record(opts : NamedTuple) : Nil
      record(**opts)
    end

    def members : Array(Breadcrumb)
      @buffer.compact
    end

    def peek
      members.last?
    end

    def each(&)
      members.each do |breadcrumb|
        yield breadcrumb
      end
    end

    def empty?
      members.empty?
    end

    def to_hash
      {
        "values" => members.map(&.to_hash),
      }
    end
  end
end

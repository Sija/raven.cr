module Raven
  class Context
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

    class_getter os_context : AnyHash::JSON do
      {
        name:           Raven.sys_command("uname -s"),
        version:        Raven.sys_command("uname -v"),
        build:          Raven.sys_command("uname -r"),
        kernel_version: Raven.sys_command("uname -a") || Raven.sys_command("ver"), # windows
      }.to_any_json
    end

    class_getter runtime_context : AnyHash::JSON do
      v = Crystal::DESCRIPTION.match /^(.+?) (\d+[^\n]+)\n+LLVM: (\d+[^\n]+)\nDefault target: (.+?)$/m
      _, name, version = v.not_nil!
      {
        name:    name,
        version: version,
      }.to_any_json
    end

    any_json_property :contexts, :extra, :tags, :user

    def initialize
      @contexts = {
        os:      self.class.os_context,
        runtime: self.class.runtime_context,
      }.to_any_json
    end
  end
end

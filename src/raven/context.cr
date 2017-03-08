module Raven
  class Context
    # FIXME
    # @[ThreadLocal]
    @@current : self?

    def self.current
      @@current ||= new
    end

    def self.clear!
      @@current = nil
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
      v = Crystal::DESCRIPTION.match /^(.+?) (\d+.*)$/
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

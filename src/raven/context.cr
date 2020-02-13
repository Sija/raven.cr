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
      self.contexts = {
        os:      self.class.os_context,
        runtime: self.class.runtime_context,
      }
      initialize_from_env
    end

    protected def initialize_from_env
      {% for key in %i(user extra tags) %}
        {% env_key = "SENTRY_CONTEXT_#{key.upcase.id}" %}

        if %context = ENV[{{ env_key }}]?.presence
          begin
            if %json = JSON.parse(%context).as_h?
              self.{{ key.id }}.merge!(%json)
            else
              raise Raven::Error.new("`{{ env_key.id }}` must contain a JSON-encoded hash")
            end
          rescue %e : JSON::ParseException
            raise Raven::Error.new("Invalid JSON string in `{{ env_key.id }}`", cause: %e)
          end
        end
      {% end %}
    end
  end
end

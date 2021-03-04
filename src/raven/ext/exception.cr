require "json"
require "yaml"

class Exception
  @[JSON::Field(ignore: true)]
  @[YAML::Field(ignore: true)]
  property __raven_event_id : String?

  {% for key in %i(user tags extra) %}
    @[JSON::Field(ignore: true)]
    @[YAML::Field(ignore: true)]
    any_json_property :__raven_{{ key.id }}
  {% end %}
end

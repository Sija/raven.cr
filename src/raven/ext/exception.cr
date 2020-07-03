class Exception
  property __raven_event_id : String?

  {% for key in %i(user tags extra) %}
    any_json_property :__raven_{{ key.id }}
  {% end %}
end

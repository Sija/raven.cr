module Raven
  class Processor::HTTPHeaders < Processor
    DEFAULT_FIELDS = ["Authorization"] of String | Regex

    property sanitize_http_headers : Array(String | Regex)

    private getter fields_pattern : Regex do
      fields = DEFAULT_FIELDS | sanitize_http_headers
      fields.map! { |field| field_pattern(field) }
      Regex.union(fields)
    end

    # Returns user-defined *field* as a pattern matching it literally,
    # and only as a whole word (`\b` wouldn't do for fields starting
    # or ending with a non-word character).
    private def field_pattern(field)
      return field if field.is_a?(Regex) || field.in?(DEFAULT_FIELDS)
      /(?<!\w)#{Regex.escape(field)}(?!\w)/
    end

    def initialize(client)
      super
      @sanitize_http_headers = client.configuration.sanitize_http_headers
    end

    def process(data)
      return data unless data.is_a?(Hash)
      data = data.to_any_json

      if headers = data[:request, :headers]?.as?(Hash)
        headers.keys.select!(&.to_s.matches?(fields_pattern)).each do |key|
          headers[key] = STRING_MASK
        end
      end
      data.to_h
    end
  end
end

module Raven
  class Processor::HTTPHeaders < Processor
    DEFAULT_FIELDS = ["Authorization"] of String | Regex

    property sanitize_http_headers : Array(String | Regex)

    private def use_boundary?(field)
      !(field.is_a?(Regex) || DEFAULT_FIELDS.includes?(field))
    end

    private getter fields_pattern : Regex {
      fields = DEFAULT_FIELDS | sanitize_http_headers
      fields.map! { |f| use_boundary?(f) ? /\b#{f}\b/ : f }
      Regex.union(fields)
    }

    def initialize(client)
      super
      @sanitize_http_headers = client.configuration.sanitize_http_headers
    end

    def process(data)
      return data unless data.is_a?(Hash)
      data = data.to_any_json

      if headers = data[:request, :headers]?.as?(Hash)
        headers.keys.select(&.to_s.match(fields_pattern)).each do |key|
          headers[key] = STRING_MASK
        end
      end
      data.to_h
    end
  end
end

require "json"

module Raven
  class Processor::SanitizeData < Processor
    DEFAULT_FIELDS = [
      "authorization", "password", "password_repeat",
      "passwd", "secret", "ssn", /social(.*)?sec/i,
    ]
    CREDIT_CARD_PATTERN = /^(?:\d[ -]*?){13,16}$/

    property sanitize_fields : Array(String | Regex)
    property? sanitize_credit_cards : Bool

    private getter fields_pattern : Regex {
      Regex.union(DEFAULT_FIELDS | sanitize_fields)
    }

    def initialize(client)
      super
      @sanitize_fields = client.configuration.sanitize_fields
      @sanitize_credit_cards = client.configuration.sanitize_credit_cards?
    end

    def process(data)
      case data
      when Hash
        data = data.each_with_object(data.to_any_json) do |(k, v), memo|
          memo[k] = process(k, v)
        end
        data.to_h
      else
        data
      end
    end

    def process(key, value)
      case value
      when Hash
        process(value)
      when Array
        value.map! { |i| process(key, i).as(typeof(i)) }
      when String
        case
        when value =~ fields_pattern && (json = parse_json_or_nil(value))
          process(json).to_json
        when matches_regexes?(key, value)
          STRING_MASK
        when key == :query_string || key == "query_string"
          sanitize_query_string(value)
        else
          value
        end
      when Number
        matches_regexes?(key, value) ? INT_MASK : value
      else
        value
      end
    end

    private def parse_json_or_nil(string)
      return unless string.starts_with?('[') || string.starts_with?('{')
      JSON.parse_raw(string) rescue nil
    end

    private def sanitize_query_string(query_string)
      query_hash = HTTP::Params.parse(query_string).to_h
      query_hash = process(query_hash)
      query_hash = query_hash.map { |k, v| [k.as(String), v.as(String)] }.to_h rescue nil
      HTTP::Params.encode(query_hash).to_s if query_hash
    end

    private def matches_regexes?(key, value)
      return true if sanitize_credit_cards? && value.to_s =~ CREDIT_CARD_PATTERN
      return true if key.to_s =~ fields_pattern
    end
  end
end

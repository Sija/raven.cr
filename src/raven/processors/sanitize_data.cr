require "json"

module Raven
  class Processor::SanitizeData < Processor
    DEFAULT_FIELDS = [
      "authorization", "password", "password_repeat",
      "passwd", "secret", "ssn", /social(.*)?sec/i,
    ]
    CREDIT_CARD_PATTERN = /\b(?:3[47]\d|(?:4\d|5[1-5]|65)\d{2}|6011)\d{12}\b/

    property sanitize_fields : Array(String | Regex)
    property sanitize_fields_excluded : Array(String | Regex)
    property? sanitize_credit_cards : Bool

    private def use_boundary?(field)
      !(field.is_a?(Regex) || DEFAULT_FIELDS.includes?(field))
    end

    private getter fields_pattern : Regex {
      fields = DEFAULT_FIELDS | sanitize_fields
      fields -= sanitize_fields_excluded
      fields.map! { |f| use_boundary?(f) ? /\b#{f}\b/ : f }
      Regex.union(fields)
    }

    def initialize(client)
      super
      @sanitize_fields = client.configuration.sanitize_fields
      @sanitize_fields_excluded = client.configuration.sanitize_fields_excluded
      @sanitize_credit_cards = client.configuration.sanitize_credit_cards?
    end

    def process(data)
      case data
      when Hash(String, JSON::Any)
        data = data.each_with_object(AnyHash::JSON.new) do |(k, v), memo|
          case v = v.raw
          when AnyHash::JSONTypes::Value
            memo[k] = process(k, v)
          end
        end
        data.to_h
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
      JSON.parse(string).raw rescue nil
    end

    private getter utf8_processor : Processor::UTF8Conversion {
      Processor::UTF8Conversion.new(@client)
    }

    private def sanitize_query_string(query_string)
      query_hash = HTTP::Params.parse(query_string).to_h
      query_hash = utf8_processor.process(query_hash)
      query_hash = process(query_hash)
      query_hash = query_hash.map { |k, v| {k.as(String), v.as(String)} }.to_h rescue nil
      HTTP::Params.encode(query_hash).to_s if query_hash
    end

    private def matches_regexes?(key, value)
      return true if sanitize_credit_cards? && value.to_s =~ CREDIT_CARD_PATTERN
      return true if key.to_s =~ fields_pattern
    end
  end
end

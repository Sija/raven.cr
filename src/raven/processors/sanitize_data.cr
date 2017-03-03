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
      case
      when value.is_a?(Hash)
        process(value)
      when value.is_a?(Array)
        value.map! { |i| process(key, i).as(typeof(i)) }
      when key.to_s == "query_string"
        if value.is_a?(String)
          sanitize_query_string(value)
        else
          value
        end
      when value.is_a?(String)
        if fields_pattern.match(value.to_s) && (json = JSON.parse_raw(value) rescue nil)
          process(json).to_json
        elsif matches_regexes?(key, value)
          STRING_MASK
        else
          value
        end
      when value.is_a?(Number) && matches_regexes?(key, value)
        INT_MASK
      else
        value
      end
    end

    private def sanitize_query_string(query_string)
      query_hash = HTTP::Params.parse(query_string).to_h
      query_hash = process(query_hash)
      query_hash = query_hash.map { |k, v| [k.as(String), v.as(String)] }.to_h rescue nil
      HTTP::Params.from_hash(query_hash).to_s if query_hash
    end

    private def matches_regexes?(key, value)
      return true if fields_pattern.match(key.to_s)
      return true if sanitize_credit_cards? && CREDIT_CARD_PATTERN.match(value.to_s)
    end
  end
end

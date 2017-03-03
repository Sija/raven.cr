module Raven
  class Processor::UTF8Conversion < Processor
    def process(data)
      case data
      when Hash
        data.each do |k, v|
          data[k] = process(v)
        end
        data.to_h
      when Array
        data.map! { |v| process(v).as(typeof(v)) }
      when String
        !data.valid_encoding? ? clean_invalid_utf8_bytes(data) : data
      else
        data
      end
    end

    private def clean_invalid_utf8_bytes(str : String)
      str = str.encode("UTF-16", invalid: :skip)
      str = String.new(str, "UTF-16")
      str = str.encode("UTF-8", invalid: :skip)
      str = String.new(str, "UTF-8")
    end
  end
end

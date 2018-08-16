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
      when Exception
        return data unless message = data.message
        return data if message.valid_encoding?
        data.class.new(clean_invalid_utf8_bytes(message), data.cause).tap do |ex|
          ex.callstack = data.callstack
        end
      when String
        return data if data.valid_encoding?
        clean_invalid_utf8_bytes(data)
      else
        data
      end
    end

    private def clean_invalid_utf8_bytes(str : String)
      str = str.encode("UTF-16", invalid: :skip)
      str = String.new(str, "UTF-16")
      str = str.encode("UTF-8", invalid: :skip)
      str = String.new(str, "UTF-8") # ameba:disable Lint/UselessAssign
    end
  end
end

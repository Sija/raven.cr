module Raven
  class Processor::Compact < Processor
    def process(data)
      return if data.responds_to?(:empty?) && data.empty?

      case data
      when Hash
        data.each do |k, v|
          data[k] = process(v)
        end
        data.compact!
        data.to_h
      when Array
        data.map! { |v| process(v).as(typeof(v)) }
      else
        data
      end
    end
  end
end

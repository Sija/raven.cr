module Raven
  class Processor::RemoveStacktrace < Processor
    def process(data)
      return data unless data.is_a?(Hash)
      data = data.to_any_json

      data[:exception, :values]?.as?(Array).try &.each do |e|
        e.as?(Hash).try &.delete(:stacktrace)
      end
      data.to_h
    end
  end
end

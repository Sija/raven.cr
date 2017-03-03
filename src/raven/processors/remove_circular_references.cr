module Raven
  class Processor::RemoveCircularReferences < Processor
    def process(data, visited = [] of UInt64)
      return data unless data.responds_to? :object_id
      return "(...)" if visited.includes? data.object_id

      case data
      when AnyHash::JSON
        visited << data.to_h.object_id
        data.each do |k, v|
          data[k] = process(v, visited) rescue "!"
        end
        data.to_h
      when Hash
        process data.to_any_json, visited
      when Array
        data.map { |v| process(v, visited).as(typeof(v)) }
      else
        data
      end
    end
  end
end

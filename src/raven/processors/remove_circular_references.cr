module Raven
  class Processor::RemoveCircularReferences < Processor
    def process(data, visited = [] of UInt64)
      return data unless data.responds_to? :object_id
      return "(...)" if visited.includes? data.object_id

      case data
      when Hash
        visited << data.object_id
        data.each do |k, v|
          data[k] = process(v, visited) rescue "!!!"
        end
        data
      when Array
        visited << data.object_id
        data.map! { |v| process(v, visited).as(typeof(v)) }
      else
        data
      end
    end
  end
end

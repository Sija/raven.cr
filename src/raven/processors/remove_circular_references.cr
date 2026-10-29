module Raven
  class Processor::RemoveCircularReferences < Processor
    def process(data, visited = [] of UInt64)
      return data unless data.is_a?(Hash) || data.is_a?(Array)
      return "(...)" if visited.includes? data.object_id

      # Holds only the ancestors of *data* (hence the `pop`), leaving values
      # referenced more than once (but not circularly) intact.
      visited << data.object_id
      begin
        case data
        in Hash
          data.each do |k, v|
            data[k] = process(v, visited) rescue "!!!"
          end
          data
        in Array
          data.map! { |v| process(v, visited).as(typeof(v)) }
        end
      ensure
        visited.pop
      end
    end
  end
end

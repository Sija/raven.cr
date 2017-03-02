module Raven
  class Processor::PostData < Processor
    REMOVE_DATA_FOR_METHODS = %w(POST PUT PATCH)

    def process(data)
      return data unless data.is_a?(Hash)
      data = data.to_any_json

      if REMOVE_DATA_FOR_METHODS.includes? data[:request, :method]?
        data[:request, :data] = nil
      end
      data.to_h
    end
  end
end

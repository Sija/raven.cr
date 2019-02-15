module Raven
  class Processor::RequestMethodData < Processor
    property request_methods : Array(String)

    def initialize(client)
      super
      @request_methods = client.configuration.sanitize_data_for_request_methods
    end

    def process(data)
      return data unless data.is_a?(Hash)
      data = data.to_any_json

      if sanitize_request_method? data[:request, :method]?
        data[:request, :data] = nil
      end
      data.to_h
    end

    private def sanitize_request_method?(verb)
      request_methods.includes?(verb)
    end
  end
end

module Raven
  class Processor::Cookies < Processor
    def process(data)
      return data unless data.is_a?(Hash)
      data = data.to_any_json

      if req = data[:request]?.as?(Hash).try(&.to_any_json)
        req[:cookies] = nil if req[:cookies]?
        if req[:headers, "Cookie"]?
          req[:headers, "Cookie"] = nil
        end
      end
      data.to_h
    end
  end
end

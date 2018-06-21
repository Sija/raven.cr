module Raven
  class Processor::Cookies < Processor
    def process(data)
      return data unless data.is_a?(Hash)
      data = data.to_any_json

      if req = data[:request]?.as?(Hash).try(&.to_any_json)
        req[:cookies] = STRING_MASK if req[:cookies]?
        if req[:headers, "Cookie"]?
          req[:headers, "Cookie"] = STRING_MASK
        end
      end
      data.to_h
    end
  end
end

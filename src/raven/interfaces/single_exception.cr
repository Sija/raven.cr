module Raven
  class Interface::SingleException < Interface
    property! type : String
    property! value : String
    property module : String?
    property stacktrace : Stacktrace?
  end
end

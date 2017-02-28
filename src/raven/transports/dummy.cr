module Raven
  class Transport::Dummy < Transport
    property events = [] of AnyHash::JSON

    def send_event(auth_header, data, **options)
      events << {
        auth_header: auth_header,
        data:        data,
        options:     options,
      }.to_any_json
    end
  end
end

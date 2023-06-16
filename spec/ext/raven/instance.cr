class Raven::Instance
  getter last_sent_event : Raven::Event?

  def send_event(event, hint = nil)
    @last_sent_event = event
  end
end

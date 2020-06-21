at_exit do |_, exception|
  if exception
    Raven::Log.debug(exception: exception) { "Caught a post-mortem exception" }
    Raven.capture(exception)
  end
end

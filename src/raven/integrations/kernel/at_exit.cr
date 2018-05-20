at_exit do |_, exception|
  if exception
    Raven.logger.debug "Caught a post-mortem exception: #{exception.inspect}"
    Raven.capture(exception)
  end
end

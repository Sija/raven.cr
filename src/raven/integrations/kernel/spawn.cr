def spawn(*, name : String? = nil, &block)
  wrapped_block = -> {
    begin
      block.call
    rescue ex
      Raven.capture(ex, tags: {
        in_fiber:   true,
        fiber_name: name,
      })
      raise ex
    end
  }
  previous_def(name: name, &wrapped_block)
end

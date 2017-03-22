lib LibC
  fun dprintf(fd : Int, format : Char*, ...) : Int
end

# :nodoc:
struct CallStack
  private def self.print_frame(repeated_frame)
    frame = decode_frame(repeated_frame.ip)
    if frame
      offset, sname = frame
      if repeated_frame.count == 0
        LibC.dprintf 2, "[0x%lx] %s +%ld\n", repeated_frame.ip, sname, offset
      else
        LibC.dprintf 2, "[0x%lx] %s +%ld (%ld times)\n", repeated_frame.ip, sname, offset, repeated_frame.count + 1
      end
    else
      if repeated_frame.count == 0
        LibC.dprintf 2, "[0x%lx] ???\n", repeated_frame.ip
      else
        LibC.dprintf 2, "[0x%lx] ??? (%ld times)\n", repeated_frame.ip, repeated_frame.count + 1
      end
    end
  end
end

# :nodoc:
@[Raises]
fun __crystal_raise(unwind_ex : LibUnwind::Exception*) : NoReturn
  ret = LibUnwind.raise_exception(unwind_ex)
  LibC.dprintf 2, "Failed to raise an exception: %s\n", ret.to_s
  CallStack.print_backtrace
  LibC.exit(ret)
end

# :nodoc:
fun __crystal_sigfault_handler(sig : LibC::Int, addr : Void*)
  # Capture fault signals (SEGV, BUS) and finish the process printing a backtrace first
  LibC.dprintf 2, "Invalid memory access (signal %ld) at address 0x%lx\n", sig, addr
  CallStack.print_backtrace
  LibC._exit sig
end

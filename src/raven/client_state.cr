module Raven
  class Client::State
    enum Status
      ONLINE
      ERROR
    end

    @status : Status
    @retry_number : Int32
    @last_check : Time?
    @retry_after : Time::Span?

    def initialize
      @status = Status::ONLINE
      @retry_number = 0
    end

    def should_try?
      return true if @status.online?

      interval = @retry_after || ({@retry_number, 6}.min ** 2).seconds
      return true unless last_check = @last_check
      return true if (Time.utc - last_check) >= interval
      false
    end

    def failure(retry_after = nil) : Nil
      @status = Status::ERROR
      @retry_number += 1
      @last_check = Time.utc
      @retry_after = retry_after
    end

    def success : Nil
      reset
    end

    def reset : Nil
      @status = Status::ONLINE
      @retry_number = 0
      @last_check = nil
      @retry_after = nil
    end

    def failed?
      @status.error?
    end
  end
end

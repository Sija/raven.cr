require "sidekiq"

module Raven
  # ```
  # require "raven/integrations/sidekiq"
  # ```
  module Sidekiq
  end
end

require "./sidekiq/*"

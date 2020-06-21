require "any_hash"

require "./raven/ext/*"
require "./raven/mixins/*"
require "./raven/*"

module Raven
  # `Raven.instance` delegators.
  module Delegators
    delegate :context, :configuration, :client,
      :report_status, :configure, :send_feedback, :send_event,
      :capture, :last_event_id, :annotate_exception,
      :user_context, :tags_context, :extra_context, :breadcrumbs,
      to: :instance
  end
end

module Raven
  extend Delegators

  class_getter instance : Raven::Instance { Raven::Instance.new }

  macro sys_command_compiled(command)
    %result = {{ `(#{command.id} || true) 2>/dev/null`.stringify.strip }}
    %result.presence
  end

  def self.sys_command(command)
    result = `(#{command}) 2>/dev/null`.strip rescue nil
    result.presence if $?.success?
  end
end

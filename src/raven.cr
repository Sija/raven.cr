require "any_hash"
require "./raven/*"

class Exception
  any_json_property __raven_context
end

module Raven
  module Delegators
    delegate :context, :logger, :configuration, :client,
      :report_status, :configure, :send_event, :capture,
      :last_event_id, :annotate_exception, :user_context,
      :tags_context, :extra_context, :breadcrumbs, to: :instance
  end
end

module Raven
  extend Delegators
  class_getter instance : Raven::Instance { Raven::Instance.new }

  def self.sys_command(command)
    result = `#{command} 2>&1`.strip rescue nil
    return if result.nil? || result.empty? || !$?.success?
    result
  end

  macro sys_command_compiled(command)
    %result = {{ system("#{command.id} || true").stringify.strip }}
    return if %result.empty?
    %result
  end
end

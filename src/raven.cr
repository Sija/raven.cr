require "any_hash"

require "./raven/ext/*"
require "./raven/mixins/*"
require "./raven/*"

module Raven
  # `Raven.instance` delegators.
  module Delegators
    delegate :context, :logger, :configuration, :client,
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
    %result unless %result.empty?
  end

  def self.sys_command(command)
    result = `(#{command}) 2>/dev/null`.strip rescue nil
    # ameba:disable Style/NegatedConditionsInUnless
    result unless result.nil? || result.empty? || !$?.success?
  end
end

module Raven
  abstract class Interface
    include Mixin::InitializeWith

    class_getter registered = {} of Symbol => Interface.class

    def self.[](name : Symbol)
      registered[name]? || raise Error.new "Unknown interface: #{name}"
    end

    def self.sentry_alias : Symbol
      {% begin %}
        raise Error.new "Undefined {{@type.id}}.sentry_alias"
      {% end %}
    end

    macro inherited
      {% factory_key = @type.name.gsub(/^Raven::Interface::/, "").underscore %}
      {% factory_key = factory_key.gsub(/::/, "_") %}

      ::Raven::Interface.registered[:{{factory_key.id}}] = self

      def initialize(**attributes)
        initialize_with(**attributes)
      end

      def initialize(**attributes, &block)
        initialize_with(**attributes)
        yield self
      end
    end

    def to_hash
      {% if @type.instance_vars.empty? %}
        return nil
      {% else %}
        {
          {% for var in @type.instance_vars %}
            :{{var.name.id}} => ((v = @{{var.name.id}}) \
              .responds_to?(:to_hash) \
                ? v.try(&.to_hash)
                : v.is_a?(Array) \
                  ? v.map { |i| i.responds_to?(:to_hash) ? i.to_hash : i }
                  : v
            ),
          {% end %}
        }
      {% end %}
    end

    def to_json(json : JSON::Builder)
      to_hash.to_json(json)
    end
  end
end

require "./interfaces/*"

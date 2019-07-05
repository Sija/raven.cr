module Raven
  abstract class Interface
    include Mixin::InitializeWith

    class_getter registered = {} of Symbol => Interface.class

    def self.[]=(name : Symbol, klass : Interface.class)
      registered[name] = klass
    end

    def self.[]?(name : Symbol) : Interface.class | Nil
      registered[name]?
    end

    def self.[](name : Symbol) : Interface.class
      self[name]? || raise ArgumentError.new "Unknown interface: #{name}"
    end

    def self.sentry_alias : Symbol
      {% begin %}
        raise "Undefined {{ @type.id }}.sentry_alias"
      {% end %}
    end

    macro inherited
      {%
        factory_key = @type.name
          .gsub(/^Raven::Interface::/, "")
          .gsub(/::/, "_")
          .underscore
          .id
      %}

      ::Raven::Interface[{{ factory_key.symbolize }}] = self

      def initialize(**attributes)
        initialize_with(**attributes)
      end

      def initialize(**attributes, &block)
        initialize_with(**attributes)
        yield self
      end
    end

    def to_hash
      {% unless @type.instance_vars.empty? %}
        {
          {% for var in @type.instance_vars %}
            {{ var.name.id.symbolize }} => ((v = @{{ var.name.id }}) \
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

    delegate :to_json, to: to_hash
  end
end

require "./interfaces/*"

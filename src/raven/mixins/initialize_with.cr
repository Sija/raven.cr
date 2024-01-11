module Raven
  module Mixin
    # Maps passed *attributes* to `@ivar_variables` and `self.property_setters=`.
    #
    # ```
    # class Foo
    #   include Raven::Mixin::InitializeWith
    #
    #   @logger : String?
    #   property message : String?
    #
    #   def backtrace=(backtrace)
    #     # ...
    #   end
    # end
    #
    # foo = Foo.new
    # foo.initialize_with({
    #   logger:    "my-logger",
    #   message:   "boo!",
    #   backtrace: caller,
    # })
    # ```
    #
    # NOTE: Magic inside!
    module InitializeWith
      def initialize_with(attributes)
        {% begin %}
          {%
            properties = @type.methods
              .select { |method| method.name.ends_with?('=') && method.args.size == 1 }
              .map(&.name[0...-1].symbolize)
              .uniq
          %}

          {% for name in properties %}
            if arg = attributes[{{ name }}]?
              self.{{ name.id }} = arg
            end
          {% end %}

          {%
            ivars = @type.instance_vars
              .map(&.name.symbolize)
              .uniq
          %}

          {% for name in ivars %}
            {% unless properties.includes?(name) %}
              if arg = attributes[{{ name }}]?
                @{{ name.id }} = arg
              end
            {% end %}
          {% end %}
        {% end %}

        self
      end

      def initialize_with(**attributes)
        initialize_with(attributes)
      end
    end
  end
end

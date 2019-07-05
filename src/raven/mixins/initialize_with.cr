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
      def initialize_with(**attributes)
        {% begin %}
          %set = [] of Symbol

          {%
            properties = @type.methods
              .select { |m| m.name.ends_with?('=') && m.args.size == 1 }
              .map(&.name[0...-1].id)
              .uniq
          %}

          {% for property in properties %}
            if arg = attributes[{{ property.symbolize }}]?
              unless %set.includes?({{ property.symbolize }})
                self.{{ property }} = arg
                %set << {{ property.symbolize }}
              end
            end
          {% end %}

          {%
            ivars = @type.instance_vars
              .map { |v| {v.name.id, v.type.name} }
              .uniq
          %}

          {% for ivar in ivars %}
            {% name = ivar[0]; type = ivar[1] %}
            if arg = attributes[{{ name.symbolize }}]?
              unless %set.includes?({{ name.symbolize }})
                if arg.is_a?({{ type }})
                  @{{ name }} = arg
                  %set << {{ name.symbolize }}
                end
              end
            end
          {% end %}
        {% end %}

        self
      end
    end
  end
end

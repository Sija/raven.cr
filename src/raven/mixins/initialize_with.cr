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

          {% properties = @type.methods.select { |m| m.name.ends_with?('=') && m.args.size == 1 } %}
          {% properties = properties.map(&.name[0...-1].id).uniq %}

          {% for property in properties %}
            if arg = attributes[:{{property}}]?
              unless %set.includes?(:{{property}})
                self.{{property}} = arg
                %set << :{{property}}
              end
            end
          {% end %}

          {% ivars = @type.instance_vars %}
          {% ivars = ivars.map { |i| [i.name.id, i.type.id] }.uniq %}

          {% for ivar in ivars %}
            {% name = ivar[0]; type = ivar[1] %}
            if arg = attributes[:{{name}}]?
              unless %set.includes?(:{{name}})
                if arg.is_a?({{type}})
                  @{{name}} = arg
                  %set << :{{name}}
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

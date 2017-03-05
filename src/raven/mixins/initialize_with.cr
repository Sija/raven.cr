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
        {% for method in @type.methods.select { |m| m.name.ends_with?('=') && m.args.size == 1 } %}
          {% property_name = method.name[0...-1].id %}
          if arg = attributes[:{{property_name}}]?
            self.{{property_name}} = arg
          end
        {% end %}
        {% for var in @type.instance_vars %}
          if arg = attributes[:{{var.name.id}}]?
            @{{var.name.id}} = arg if arg.is_a?({{var.type.id}})
          end
        {% end %}
        self
      end
    end
  end
end

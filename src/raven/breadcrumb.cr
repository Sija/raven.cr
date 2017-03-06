module Raven
  class Breadcrumb
    # The type of breadcrumb. The default type is `Type::DEFAULT` which indicates
    # no specific handling. Other types are currently:
    # - `Type::HTTP` for HTTP requests and
    # - `Type::NAVIGATION` for navigation events.
    enum Type
      DEFAULT
      HTTP
      NAVIGATION
    end

    # Levels are used in the UI to emphasize and deemphasize the crumb.
    enum Severity
      DEBUG
      INFO
      WARNING
      ERROR
      CRITICAL
    end

    # A timestamp representing when the breadcrumb occurred.
    property timestamp : Time

    # The type of breadcrumb. The default type is `:default` which indicates
    # no specific handling. Other types are currently:
    # - `:http` for HTTP requests and
    # - `:navigation` for navigation events.
    property type : Type?

    # ditto
    def type=(type : Symbol)
      @type = Type.parse(type.to_s)
    end

    # If a message is provided it’s rendered as text and the whitespace is preserved.
    # Very long text might be abbreviated in the UI.
    property message : String?

    # Categories are dotted strings that indicate what the crumb is or where it comes from.
    # Typically it’s a module name or a descriptive string.
    # For instance `ui.click` could be used to indicate that a click happened
    # in the UI or `flask` could be used to indicate that the event originated
    # in the Flask framework.
    property category : String?

    # This defines the level of the event. If not provided it defaults
    # to `info` which is the middle level.
    property level : Severity?

    # ditto
    def level=(severity : Symbol)
      @level = Severity.parse(severity.to_s)
    end

    # Data associated with this breadcrumb. Contains a sub-object whose
    # contents depend on the breadcrumb `type`. Additional parameters that
    # are unsupported by the type are rendered as a key/value table.
    any_json_property :data

    def initialize
      @timestamp = Time.now
    end

    def to_hash
      {
        "timestamp" => @timestamp.to_utc.epoch,
        "type"      => @type.try(&.to_s.downcase),
        "message"   => @message,
        "data"      => data.to_h,
        "category"  => @category,
        "level"     => @level.try(&.to_s.downcase),
      }
    end
  end
end

require "./breadcrumbs/*"

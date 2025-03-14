require "../spec_helper"

describe Raven::Context do
  {% for key in %i[user extra tags] %}
    {% env_key = "SENTRY_CONTEXT_#{key.upcase.id}" %}

    context %(with ENV["{{ env_key.id }}"]?) do
      it "initializes from valid JSON-encoded string" do
        with_clean_env do
          ENV[{{ env_key }}] = {foo: :bar}.to_json

          context = Raven::Context.new
          context.{{ key.id }}.should eq({"foo" => "bar"})
        end
      end

      it "raises when JSON-encoded string is not a Hash" do
        with_clean_env do
          ENV[{{ env_key }}] = (0..3).to_a.to_json

          expect_raises(Raven::Error, {{ env_key }}) do
            Raven::Context.new
          end
        end
      end

      it "raises on invalid JSON-encoded string" do
        with_clean_env do
          ENV[{{ env_key }}] = "foo"

          expect_raises(Raven::Error, {{ env_key }}) do
            Raven::Context.new
          end
        end
      end
    end
  {% end %}
end

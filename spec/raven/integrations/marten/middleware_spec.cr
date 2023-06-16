require "marten"
require "marten/spec"

require "../../../../src/raven/integrations/marten"

require "./spec_helper"

private def with_clean_configuration(&)
  prev_configuration = Raven.instance.configuration.dup
  begin
    Raven.instance.configuration = build_configuration
    yield
  ensure
    Raven.instance.configuration = prev_configuration
  end
end

describe Raven::Marten::Middleware do
  around_each do |t|
    original_allowed_hosts = Marten.settings.allowed_hosts

    Marten.settings.allowed_hosts = %w(example.com www.example.com)

    with_clean_configuration { t.run }

    Marten.settings.allowed_hosts = original_allowed_hosts
  end

  describe "#call" do
    it "returns the response as expected if no error occurs" do
      middleware = Raven::Marten::Middleware.new

      response = middleware.call(
        Marten::HTTP::Request.new(
          method: "GET",
          resource: "/foo/bar",
          headers: HTTP::Headers{"Host" => "example.com"}
        ),
        ->{ Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200) }
      )

      response.should be_a Marten::HTTP::Response
      response.content.should eq "It works!"
    end

    it "properly sets the event culprit when capturing an exception" do
      middleware = Raven::Marten::Middleware.new

      expect_raises(DivisionByZeroError) do
        middleware.call(
          Marten::HTTP::Request.new(
            method: "GET",
            resource: "/foo/bar",
            headers: HTTP::Headers{"Host" => "example.com"}
          ),
          ->{
            1 // 0
            Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200)
          }
        )
      end

      event = Raven.instance.last_sent_event
      event.try(&.culprit).should eq "GET /foo/bar"
    end

    it "properly sets the event logger when capturing an exception" do
      middleware = Raven::Marten::Middleware.new

      expect_raises(DivisionByZeroError) do
        middleware.call(
          Marten::HTTP::Request.new(
            method: "GET",
            resource: "/foo/bar",
            headers: HTTP::Headers{"Host" => "example.com"}
          ),
          ->{
            1 // 0
            Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200)
          }
        )
      end

      event = Raven.instance.last_sent_event
      event.try(&.logger).should eq "marten"
    end

    it "properly sets the HTTP interface when capturing an exception for a GET request" do
      middleware = Raven::Marten::Middleware.new

      expect_raises(DivisionByZeroError) do
        middleware.call(
          Marten::HTTP::Request.new(
            method: "GET",
            resource: "/foo/bar?foo=bar&xyz=test",
            headers: HTTP::Headers{"Host" => "example.com"}
          ),
          ->{
            1 // 0
            Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200)
          }
        )
      end

      event = Raven.instance.last_sent_event
      http_interface = event.try { |e| e.interface(:http).as(Raven::Interface::HTTP) }

      http_interface.try(&.method).should eq "GET"
      http_interface.try(&.url).should eq "http://example.com/foo/bar?foo=bar&xyz=test"
      http_interface.try(&.headers).should eq({"Host" => ["example.com"]})
      http_interface.try(&.query_string).should eq "foo=bar&xyz=test"
      http_interface.try(&.data.should(be_empty))
    end

    it "properly sets the HTTP interface when capturing an exception for a POST request" do
      middleware = Raven::Marten::Middleware.new

      expect_raises(DivisionByZeroError) do
        middleware.call(
          Marten::HTTP::Request.new(
            method: "POST",
            resource: "/foo/bar?param=val",
            headers: HTTP::Headers{"Host" => "example.com", "Content-Type" => "application/x-www-form-urlencoded"},
            body: "foo=bar&test=xyz&foo=baz"
          ),
          ->{
            1 // 0
            Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200)
          }
        )
      end

      event = Raven.instance.last_sent_event
      http_interface = event.try { |e| e.interface(:http).as(Raven::Interface::HTTP) }

      http_interface.try(&.method).should eq "POST"
      http_interface.try(&.url).should eq "http://example.com/foo/bar?param=val"
      http_interface.try(&.headers).should eq(
        {"Host" => ["example.com"], "Content-Type" => ["application/x-www-form-urlencoded"], "Content-Length" => ["24"]}
      )
      http_interface.try(&.query_string).should eq "param=val"
      http_interface.try(&.data).should eq({"foo" => ["bar", "baz"], "test" => ["xyz"]})
    end

    it "properly sets the HTTP interface when capturing an exception for a PUT request" do
      middleware = Raven::Marten::Middleware.new

      expect_raises(DivisionByZeroError) do
        middleware.call(
          Marten::HTTP::Request.new(
            method: "PUT",
            resource: "/foo/bar?param=val",
            headers: HTTP::Headers{"Host" => "example.com", "Content-Type" => "application/x-www-form-urlencoded"},
            body: "foo=bar&test=xyz&foo=baz"
          ),
          ->{
            1 // 0
            Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200)
          }
        )
      end

      event = Raven.instance.last_sent_event
      http_interface = event.try { |e| e.interface(:http).as(Raven::Interface::HTTP) }

      http_interface.try(&.method).should eq "PUT"
      http_interface.try(&.url).should eq "http://example.com/foo/bar?param=val"
      http_interface.try(&.headers).should eq(
        {"Host" => ["example.com"], "Content-Type" => ["application/x-www-form-urlencoded"], "Content-Length" => ["24"]}
      )
      http_interface.try(&.query_string).should eq "param=val"
      http_interface.try(&.data).should eq({"foo" => ["bar", "baz"], "test" => ["xyz"]})
    end

    it "properly sets the HTTP interface when capturing an exception for a PATCH request" do
      middleware = Raven::Marten::Middleware.new

      expect_raises(DivisionByZeroError) do
        middleware.call(
          Marten::HTTP::Request.new(
            method: "PATCH",
            resource: "/foo/bar?param=val",
            headers: HTTP::Headers{"Host" => "example.com", "Content-Type" => "application/x-www-form-urlencoded"},
            body: "foo=bar&test=xyz&foo=baz"
          ),
          ->{
            1 // 0
            Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200)
          }
        )
      end

      event = Raven.instance.last_sent_event
      http_interface = event.try { |e| e.interface(:http).as(Raven::Interface::HTTP) }

      http_interface.try(&.method).should eq "PATCH"
      http_interface.try(&.url).should eq "http://example.com/foo/bar?param=val"
      http_interface.try(&.headers).should eq(
        {"Host" => ["example.com"], "Content-Type" => ["application/x-www-form-urlencoded"], "Content-Length" => ["24"]}
      )
      http_interface.try(&.query_string).should eq "param=val"
      http_interface.try(&.data).should eq({"foo" => ["bar", "baz"], "test" => ["xyz"]})
    end

    it "properly sets the cookies in the HTTP interface" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/foo/bar",
        headers: HTTP::Headers{"Host" => "example.com"}
      )
      request.cookies["test"] = "value"

      middleware = Raven::Marten::Middleware.new

      expect_raises(DivisionByZeroError) do
        middleware.call(
          request,
          ->{
            1 // 0
            Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200)
          }
        )
      end

      event = Raven.instance.last_sent_event
      http_interface = event.try { |e| e.interface(:http).as(Raven::Interface::HTTP) }

      http_interface.try(&.cookies).should eq "test=value"
    end

    it "does not capture HTTP not found exceptions" do
      middleware = Raven::Marten::Middleware.new

      expect_raises(Marten::HTTP::Errors::NotFound) do
        middleware.call(
          Marten::HTTP::Request.new(
            method: "PUT",
            resource: "/foo/bar?param=val",
            headers: HTTP::Headers{"Host" => "example.com", "Content-Type" => "application/x-www-form-urlencoded"},
            body: "foo=bar&test=xyz&foo=baz"
          ),
          ->{
            raise Marten::HTTP::Errors::NotFound.new("This is bad")
            Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200)
          }
        )

        Raven.instance.last_sent_event.should be_nil
      end
    end

    it "does not capture route not found exceptions" do
      middleware = Raven::Marten::Middleware.new

      expect_raises(Marten::Routing::Errors::NoResolveMatch) do
        middleware.call(
          Marten::HTTP::Request.new(
            method: "PUT",
            resource: "/foo/bar?param=val",
            headers: HTTP::Headers{"Host" => "example.com", "Content-Type" => "application/x-www-form-urlencoded"},
            body: "foo=bar&test=xyz&foo=baz"
          ),
          ->{
            raise Marten::Routing::Errors::NoResolveMatch.new("This is bad")
            Marten::HTTP::Response.new("It works!", content_type: "text/plain", status: 200)
          }
        )

        Raven.instance.last_sent_event.should be_nil
      end
    end
  end
end

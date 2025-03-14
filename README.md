<p align="center">
  <img src="https://sija.github.io/raven.cr/img/bug-fixing.svg" height="300" alt="Bug fixing illustration" />
</p>

<h1 align="center">
  raven.cr • the Crystal client for Sentry
</h1>

<p align="center">
  <a href="https://github.com/Sija/raven.cr/actions/workflows/ci.yml"><img src="https://github.com/Sija/raven.cr/actions/workflows/ci.yml/badge.svg" alt="Build Status" /></a>
  <a href="https://app.codacy.com/gh/Sija/raven.cr/dashboard"><img src="https://app.codacy.com/project/badge/Grade/32cb8814a14d4a6cbe39d6768142c59b" alt="Codacy badge"/></a>
  <a href="https://github.com/Sija/raven.cr/releases"><img src="https://img.shields.io/github/release/Sija/raven.cr.svg" alt="Releases" /></a>
  <a href="https://github.com/Sija/raven.cr/blob/master/LICENSE"><img src="https://img.shields.io/github/license/Sija/raven.cr.svg" alt="License" /></a>
</p>

An unofficial Crystal-language client and integration layer for the [Sentry](https://github.com/getsentry/sentry) error reporting API.

Based on fine [raven-ruby](https://github.com/getsentry/raven-ruby) gem
from folks at [@getsentry](https://github.com/getsentry).

### Blog posts

- [Crystal error tracking with Sentry](https://sija.pl/en/notes/crystal-error-tracking-with-sentry)
- [Sentry error tracking for Kemal](https://sija.pl/en/notes/sentry-error-tracking-for-kemal)

## Features

- [x] Processors (data scrubbers)
- [x] Interfaces (Message, Exception, Stacktrace, User, HTTP, ...)
- [x] Contexts (user, tags, extra, os, runtime)
- [x] Breadcrumbs
- [x] Integrations ([Kemal](https://github.com/kemalcr/kemal), [Amber](https://github.com/amberframework/amber), [Lucky](https://github.com/luckyframework/lucky), [Sidekiq.cr](https://github.com/mperham/sidekiq.cr), [action-controller](https://github.com/spider-gazelle/action-controller))
- [x] Async support
- [x] User Feedback
- [x] Source code context for stack traces
- [x] Dedicated [`Log`](https://crystal-lang.org/api/Log.html) backend
- [x] Crash Handler

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  raven:
    github: Sija/raven.cr
```

## Usage

```crystal
require "raven"
```

### Raven only runs when SENTRY_DSN is set

Raven will capture and send exceptions to the Sentry server whenever its DSN is set.
This makes environment-based configuration easy - if you don't want to send
errors in a certain environment, just don't set the DSN in that environment!

```sh
# Set your SENTRY_DSN environment variable.
export SENTRY_DSN=https://public@example.com/project-id
```

```crystal
# Or you can configure the client in the code (not recommended - keep your DSN secret!)
Raven.configure do |config|
  config.dsn = "https://public@example.com/project-id"
end
```

### Raven doesn't report some kinds of data by default

If used with integrations, Raven ignores some exceptions by default - most of
these are related to 404s or controller actions not being found.

Raven doesn't report `POST`, `PUT`, `PATCH` data or cookies by default.
In addition, it will attempt to remove any obviously sensitive data,
such as credit card or Social Security numbers.
For more information about how Sentry processes your data, [check out the documentation on the `processors` config setting.](https://docs.sentry.io/clients/ruby/config/)

### Call

Raven supports two methods of capturing exceptions:

```crystal
Raven.capture do
  # capture any exceptions which happen during execution of this block
  1 // 0
end

begin
  1 // 0
rescue ex : DivisionByZeroError
  Raven.capture(ex)
end
```

### More configuration

You're all set - but there are a few more settings you may want to know about too!

#### DSN

While we advise that you set your Sentry DSN through the `SENTRY_DSN` environment
variable, there are two other configuration settings for controlling Raven:

```crystal
# DSN can be configured as a config setting instead.
# Place in config/initializers or similar.
Raven.configure do |config|
  config.dsn = "your_dsn"
end
```

And, while not necessary if using `SENTRY_DSN`, you can also provide an
`environments` setting. Raven will only capture events when
`SENTRY_ENVIRONMENT` matches an environment on the list.

```crystal
Raven.configure do |config|
  config.environments = %w[staging production]
end
```

#### async

When an error or message occurs, the notification is immediately sent to Sentry.
Raven can be configured to send asynchronously:

```crystal
# define your own handler
config.async = ->(event : Raven::Event) {
  spawn { Raven.send_event(event) }
}
# or use default implementation based on fibers (i.e. the one above)
config.async = true
```

If the `async` callback raises an exception, Raven will attempt to send synchronously.

We recommend creating a background job, using your background job processor,
that will send Sentry notifications in the background.
Rather than enqueuing an entire `Raven::Event` object, we recommend providing
the `Hash` representation of an event as a job argument.

Here’s an example for *Sidekiq.cr*:

```crystal
config.async = ->(event : Raven::Event) {
  # enqueue the job with a hash...
  SentryJob.async.perform(event.to_hash)
  # or with JSON string
  # SentryJob.async.perform(event.to_json)
}

class SentryJob
  include Sidekiq::Worker

  sidekiq_options do |job|
    job.queue = "sentry"
    job.retry = true
  end

  def perform(event : Raven::Event::HashType)
    Raven.send_event(event)
  end
end
```

#### transport_failure_callback

If Raven fails to send an event to Sentry for any reason
(either the Sentry server has returned a 4XX or 5XX response),
this `Proc` will be called.

```crystal
config.transport_failure_callback = ->(event : Raven::Event::HashType) {
  AdminMailer.async.perform("Oh god, it's on fire!", event)
}
```

#### Context

Much of the usefulness of Sentry comes from additional context data with the events.
Raven makes this very convenient by providing methods to set context data that
is then submitted automatically with all events.

There are three primary methods for providing request context:

```crystal
# bind the logged in user
Raven.user_context email: "foo@example.com"

# tag the request with something interesting
Raven.tags_context interesting: "yes"

# provide a bit of additional context
Raven.extra_context happiness: "very"
```

For more information, see [Context](https://docs.sentry.io/clients/ruby/context/).

## `Log` backend

`Raven::LogBackend` allows for intercepting log entries, and takes following options:

- `record_breadcrumbs` - records every log entry as Breadcrumbs
- `capture_exceptions` - captures exceptions attached to the log entry
- `capture_all` - captures every log entry

Every captured `Exception` or a `Breadcrumb` will have corresponding fields mapped
directly from the original `Log::Entry`.

Metadata will be passed as `Event#tags` and `Breadcrumb#data`, respectively.

### Usage

```crystal
# append it to the existing bindings
Log.builder.bind "*", :info, Raven::LogBackend.new(
  record_breadcrumbs: true,
  capture_exceptions: false,
  capture_all: false,
)

# or bind it within the `Log.setup` block
Log.setup do |c|
  # bind the regular io-based backend
  c.bind "*", :info, Log::IOBackend.new

  # bind raven's backend
  c.bind "*", :info, Raven::LogBackend.new(record_breadcrumbs: true)
  c.bind "*", :warn, Raven::LogBackend.new(capture_exceptions: true)
  c.bind "*", :fatal, Raven::LogBackend.new(capture_all: true)
end
```

See more in Crystal's `Log` [documentation](https://crystal-lang.org/api/Log.html#configure-logging-explicitly-in-the-code).

## Crash Handler

Since Crystal doesn't provide native handlers for unhandled exceptions
and segfaults, *raven.cr* introduces its own crash handler compiled as
external binary.

### Setup

The easiest way of using it is by adding the appropriate entry to the project's `shard.yml`:

```yaml
targets:
  # other target definitions if any...

  sentry.crash_handler:
    main: lib/raven/src/crash_handler.cr
```

With the above entry defined in `targets`, running `shards build` should result in
binary built in `bin/sentry.crash_handler`.

__NOTE__: While building you might specify `SENTRY_DSN` env variable, which will be
compiled into the binary (as plain-text) and used by the handler.

```sh
SENTRY_DSN=<your_dsn> shards build sentry.crash_handler
```

Pass `--release` flag to disable debug messages.

### Usage

You need to run your app with previously built `bin/sentry.crash_handler` in
front.

```sh
bin/sentry.crash_handler bin/your_app --some arguments --passed to your program
```

As one would expect, `STDIN` is passed to the original process, while
`STDOUT` and `STDERR` are piped back from it.

__NOTE__: You can always pass `SENTRY_DSN` env variable during execution
in case you didn't do it while building the wrapper.

## More Information

- [Documentation](https://docs.sentry.io/clients/ruby)
- [Bug Tracker](https://github.com/Sija/raven.cr/issues)
- [Code Repository](https://github.com/Sija/raven.cr)

## Contributing

1. [Fork it](https://github.com/Sija/raven.cr/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new [Pull Request](https://github.com/Sija/raven.cr/pulls)

## Contributors

- [@Sija](https://github.com/Sija) Sijawusz Pur Rahnama - creator, maintainer

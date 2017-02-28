# raven.cr [![Build Status](https://travis-ci.org/Sija/raven.cr.svg?branch=master)](https://travis-ci.org/Sija/raven.cr)

A client and integration layer for the [Sentry](https://github.com/getsentry/sentry) error reporting API.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  raven:
    github: sija/raven.cr
```

## Usage

```crystal
require "raven"
```

### Raven only runs when SENTRY_DSN is set

Raven will capture and send exceptions to the Sentry server whenever its DSN is set. This makes environment-based configuration easy - if you don't want to send errors in a certain environment, just don't set the DSN in that environment!

```bash
# Set your SENTRY_DSN environment variable.
export SENTRY_DSN=http://public:secret@example.com/project-id
```

```crystal
# Or you can configure the client in the code (not recommended - keep your DSN secret!)
Raven.configure do |config|
  config.server = "http://public:secret@example.com/project-id"
end
```

### Raven doesn't report some kinds of data by default.

Raven ignores some exceptions by default - most of these are related to 404s or controller actions not being found. [For a complete list, see the `IGNORE_DEFAULT` constant](https://github.com/sija/raven.cr/blob/master/src/raven/configuration.cr).

Raven doesn't report POST data or cookies by default. In addition, it will attempt to remove any obviously sensitive data, such as credit card or Social Security numbers. For more information about how Sentry processes your data, [check out the documentation on the `processors` config setting.](https://docs.sentry.io/clients/ruby/config/)

### Call

Raven supports two methods of capturing exceptions:

```crystal
Raven.capture do
  # capture any exceptions which happen during execution of this block
  1 / 0
end

begin
  1 / 0
rescue exception : DivisionByZero
  Raven.capture(exception)
end
```

### More configuration

You're all set - but there's a few more settings you may want to know about too!

#### DSN

While we advise that you set your Sentry DSN through the `SENTRY_DSN` environment
variable, there are two other configuration settings for controlling Raven:

```crystal
# DSN can be configured as a config setting instead.
# Place in config/initializers or similar.
Raven.configure do |config|
  config.server = "your_dsn"
end
```

And, while not necessary if using `SENTRY_DSN`, you can also provide an `environments`
setting. Raven will only capture events when `KEMAL_ENV` matches an environment in the list.

```crystal
Raven.configure do |config|
  config.environments = %w[staging production]
end
```

#### transport_failure_callback

If Raven fails to send an event to Sentry for any reason (either the Sentry server has returned a 4XX or 5XX response), this Proc will be called.

```crystal
config.transport_failure_callback = ->(event : Raven::Event) {
  AdminMailer.email_admins("Oh god, it's on fire!", event.to_hash).deliver_later
}
```

#### Context

Much of the usefulness of Sentry comes from additional context data with the events. Raven makes this very convenient by providing methods to set thread local context data that is then submitted automatically with all events.

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

## TODO

- [x] Configuration
- [x] Connection to Sentry server
- [ ] Exponential backoff in case of connection error
- [x] Interfaces
- [x] Connection transports
- [x] Processors
- [x] Breadcrumbs
- [ ] Integrations (Kemal, Sidekiq)
- [ ] Async
- [ ] Tests

## Development

```
crystal spec
```

## More Information

* [Documentation](https://docs.sentry.io/clients/ruby)
* [Bug Tracker](https://github.com/sija/raven.cr/issues)
* [Code](https://github.com/sija/raven.cr)
* [Mailing List](https://groups.google.com/group/getsentry)
* [IRC](irc://irc.freenode.net/sentry) (irc.freenode.net, #sentry)

## Contributing

1. [Fork it](https://github.com/sija/raven.cr/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new [Pull Request](https://github.com/sija/raven.cr/pulls)

## Contributors

- [sija](https://github.com/sija) Sijawusz Pur Rahnama - creator, maintainer

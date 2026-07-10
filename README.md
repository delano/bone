# Bone

**Remote environment variables over Valkey/Redis.**

Bone is a small Ruby client and CLI for storing and retrieving remote
key/value pairs, scoped to a token. It's designed as a lightweight store of
**remote environment variables** — generate a token for an environment (say,
staging), push variables into it, and pull them back out at deploy or boot
time.

> **Note:** Version 0.4 is a ground-up modernization for Ruby 3.2+. The
> internals were rewritten against [Familia](https://github.com/delano/familia)
> v2 and the legacy EventMachine HTTP backend was removed. It is **not**
> compatible with the 0.3.x API.

## Installation

```ruby
# Gemfile
gem 'bone'
```

```console
$ bundle install
# or
$ gem install bone
```

Requires Ruby 3.2+. The `redis://` / `valkey://` backend talks to a
Valkey/Redis server via Familia; the `memory://` backend has no external
dependencies.

## Configuring the source

Bone selects a backend from the source URI. The default is
`redis://127.0.0.1:6379/0`, overridable with the `BONE_SOURCE` environment
variable or in Ruby:

```ruby
Bone.source = 'redis://staging-redis.internal:6379/0'
Bone.source = 'memory://localhost'   # process-local, great for tests
```

| Scheme                        | Backend  | Persistence            |
| ----------------------------- | -------- | ---------------------- |
| `redis://`, `rediss://`, `valkey://` | Familia v2 | Valkey/Redis   |
| `memory://`                   | In-memory | Process lifetime      |

## Tokens and credentials

Every variable lives under a token. Generate one per environment:

```console
$ bone generate
# Your token for redis://127.0.0.1:6379/0
BONE_TOKEN=Qh8mZ2v…
BONE_SECRET=oJ3…
```

Export those into your shell (or CI secret store), and the CLI and library
pick them up from `BONE_TOKEN` / `BONE_SECRET`.

```ruby
Bone.credentials = "#{token}:#{secret}"   # or set $BONE_TOKEN / $BONE_SECRET
```

## Library usage

```ruby
require 'bone'

Bone.source      = 'redis://127.0.0.1:6379/0'
Bone.credentials = "#{token}:#{secret}"

Bone[:database_url] = 'postgres://…'
Bone[:database_url]                 # => "postgres://…"
Bone.key?(:database_url)            # => true
Bone.keys('database_*')             # => ["database_url"]

# Remote environment variables
Bone.env                            # => { "database_url" => "postgres://…" }
Bone.import("LOG_LEVEL=debug\nWORKERS=4\n")
Bone.load_env!                      # copies every variable into ENV
```

An explicit client avoids the ambient token:

```ruby
client = Bone.new(token, secret)
client[:api_key] = 'sk-…'
client.to_h
```

## CLI

```console
$ bone set database_url postgres://…
$ bone get database_url
postgres://…

$ cat .env.staging | bone import         # load a dotenv file
$ bone keys 'DB_*'
$ bone env                               # KEY=value (dotenv format)
$ eval "$(bone export)"                  # export into the current shell
```

Global options `--source`, `--token`, and `--secret` override the environment
on any command.

### Injecting staging env vars at boot

```console
# In your staging service's entrypoint:
export BONE_SOURCE=redis://staging-redis.internal:6379/0
export BONE_TOKEN=… BONE_SECRET=…
eval "$(bone export)"
exec your-service
```

## Development

```console
$ bundle install
$ bundle exec rake test      # tryouts suite (needs a Valkey/Redis for the redis backend)
$ bundle exec rubocop
```

The `memory://`, env-layer, and client tests run without a server; the
`redis://` tests use `BONE_SOURCE` (CI provides a Valkey service). See
[`docs/http-rest-api.md`](docs/http-rest-api.md) for the archived design of the
old signed HTTP REST API, kept for reference as we revisit that surface.

## License

MIT — see [LICENSE.txt](LICENSE.txt). Copyright (c) Delano Mandelbaum,
Solutious Inc.

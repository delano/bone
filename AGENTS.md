# AGENTS.md

Guidance for AI coding agents working in this repository.

## What Bone is

A small client + CLI for **remote environment variables**: token-scoped
key/value pairs stored in Valkey/Redis (via Familia v2) or in memory. Version
0.4 is a Ruby 3.2+ rewrite; the legacy EventMachine HTTP backend and the
`drydock`/`jeweler`/`VERSION.yml` tooling were removed.

## Development commands

- **Install**: `bundle install`
- **Test**: `bundle exec rake test` (Tryouts v3; auto-discovers `try/*_try.rb`)
- **Lint**: `bundle exec rubocop`
- Redis-backed tryouts read `BONE_SOURCE` (e.g.
  `BONE_SOURCE=redis://127.0.0.1:6379/0`). The `memory://`, env-layer, and
  client tryouts need no server.

## Architecture

- `lib/bone.rb` — the `Bone` class. Class methods hold config
  (`source`/`backend`), ambient credentials (`token`/`secret`, defaulting to
  `$BONE_TOKEN`/`$BONE_SECRET`), token lifecycle (`generate`/`register`/
  `destroy`/`token?`), and delegate storage to an ambient `Bone::Client`.
- `Bone::Client` — a token/secret-bound client; the actual `get`/`set`/`keys`/
  `to_h`/`import`/`load_env!` live here.
- `lib/bone/backends.rb` — scheme → backend registry. A backend implements the
  contract documented at the top of that file.
- `lib/bone/backends/memory.rb` — process-local store (no deps).
- `lib/bone/backends/redis.rb` — Familia v2 backend. Lazily `require 'familia'`
  and defines a named `Token < Familia::Horreum` with
  `identifier_field :token`, `field :token`, `field :secret`, `hashkey :vars`.
  Values are stored as strings in the `vars` hash.
- `lib/bone/env.rb` — pure dotenv parse / dump / shell-export helpers.
- `lib/bone/cli.rb` + `exe/bone` — Dry::CLI command layer (loaded lazily; not
  required by `require 'bone'`).

## Conventions

- Ruby 3.2+ only. Every `lib/` file carries `# frozen_string_literal: true`.
- Single-quoted strings, leading dot for multiline chains (see `.rubocop.yml`).
- Stored values are always coerced to strings (`value.to_s`), matching the
  environment-variable model.
- Prefer `gsub` **block form** when the replacement contains backslashes or
  quotes (avoids `\1`/`\'` replacement-string interpretation) — see
  `Bone::Env`.

## Familia v2 notes (for the redis backend)

- Configure with `Familia.uri = '<uri>'`; connections are lazy via
  `Familia.dbclient`.
- `Horreum.exists?(id)` / `Horreum.load(id)` / instance `#save` / `#destroy!`.
- `hashkey` API used here: `[]`, `[]=` (immediate HSET), `keys`, `key?`, `all`
  (deserialized hash), `remove`, `clear`.
- Reserved Horreum field names include `ttl`, `db`, `valkey`, `redis` — avoid.

## See also

- `docs/http-rest-api.md` — archived design of the old signed HTTP REST API and
  the open questions to revisit before rebuilding a networked backend.

# try/50_redis_backend_try.rb
#
# Exercises the Valkey/Redis (Familia v2) backend. Requires a running
# Valkey/Redis server. Point at it with BONE_SOURCE, e.g.
#
#   BONE_SOURCE=redis://127.0.0.1:6379/15 bundle exec try try/50_redis_backend_try.rb
#
# The local default is DB index 15 (a throwaway DB) so a stray local run
# never touches DB 0. CI provides a valkey service and sets BONE_SOURCE,
# which still wins over the default.
#
# F8 skip guard: Tryouts v3 has no first-class per-test skip, so this file
# probes connectivity once in setup. When no server is reachable, the
# `check {}` helper returns the pass value (true) WITHOUT touching the store,
# so every assertion (`#=> true`) holds and the whole file skips cleanly
# (green, non-failing) instead of erroring. The real assertions run in CI.

require 'bone'

# Probe connectivity once. Setting the source only selects the backend (lazy);
# token? forces a real connection but writes nothing.
#
# Skip vs. fail: a probe failure degrades to a clean skip ONLY for the local
# default source. When BONE_SOURCE is set explicitly (CI), the caller is
# asserting a backend is present, so any probe failure -- server down, familia
# missing, or an implementation error masquerading as a connection error -- is
# a hard failure. Otherwise CI could go green without ever exercising Redis.
@explicit_source = !ENV['BONE_SOURCE'].to_s.empty?
Bone.source = ENV['BONE_SOURCE'] || 'redis://127.0.0.1:6379/15'
@redis_up = begin
  Bone.token?('__connectivity_probe__')
  true
rescue LoadError, StandardError => e
  raise if @explicit_source
  # Write to the real STDERR (fd 2): Tryouts captures $stderr during setup, so
  # `warn` here would be swallowed and the skip would be silent.
  STDERR.puts "# SKIP: no Redis/Valkey at #{Bone.source} (#{e.class}: #{e.message})"
  false
end

# Tokens created by this file, destroyed in teardown even after a mid-file
# failure so nothing leaks into the shared store.
@tokens = []

# Run a store-touching block only when a server is reachable; otherwise return
# the pass value so the `#=> true` assertion holds and the test skips cleanly.
def check
  @redis_up ? yield : true
end

## Selects the redis backend
# Wrapped in check: resolving the backend and its lazily-defined model both
# load familia, so an unguarded call would error (not skip) when the backend
# is unavailable.
check { Bone.backend == Bone::Backends::Redis }
#=> true

## The lazily-defined Token model is a Familia::Horreum
check { Bone::Backends::Redis.model.ancestors.include?(Familia::Horreum) }
#=> true

## Generates and registers a token
check do
  @token, @secret = *Bone.generate
  @tokens << @token
  Bone.token?(@token)
end
#=> true

## Secret round-trips through the store
check { Bone.backend.secret(@token) == @secret }
#=> true

## Set and get a value
check do
  Bone.credentials = "#{@token}:#{@secret}"
  Bone[:api_key] = 'sk-test-123'
  Bone[:api_key] == 'sk-test-123'
end
#=> true

## Non-string values are stored as strings
check do
  Bone[:replicas] = 3
  Bone[:replicas] == '3'
end
#=> true

## key? reflects presence
check { Bone.key?(:api_key) }
#=> true

## keys lists variable names
check { Bone.keys.sort == ['api_key', 'replicas'] }
#=> true

## env returns the full hash
check { Bone.env == { 'api_key' => 'sk-test-123', 'replicas' => '3' } }
#=> true

## delete removes a variable
check do
  Bone.delete(:replicas)
  Bone.key?(:replicas) == false
end
#=> true

# -- F4: unknown-token read contract on the Redis side --------------------
# Reads through a token that is not in the store return benign defaults;
# only a write raises (F6). Locks the same contract as the memory backend.

## Unknown token: get returns nil
check { Bone.new('no-such-token').get(:x).nil? }
#=> true

## Unknown token: keys returns empty
check { Bone.new('no-such-token').keys == [] }
#=> true

## Unknown token: key? returns false
check { Bone.new('no-such-token').key?(:x) == false }
#=> true

## Unknown token: all/env returns empty
check { Bone.new('no-such-token').to_h == {} }
#=> true

## Unknown token: delete returns false
check { Bone.new('no-such-token').delete(:x) == false }
#=> true

# -- F6: error and edge branches ------------------------------------------

## Unknown token: set raises NoToken (only write raises)
check do
  Bone.new('no-such-token').set(:x, 'v')
  false
rescue Bone::NoToken
  true
end
#=> true

## Duplicate register raises TokenExists
check do
  Bone.register(@token, 'other')
  false
rescue Bone::TokenExists
  true
end
#=> true

## Destroy of an unknown token returns false
check { Bone.destroy('no-such-token') == false }
#=> true

## Delete of a missing key on a known token returns false
check { Bone.new(@token, @secret).delete(:definitely_absent) == false }
#=> true

# -- lifecycle ------------------------------------------------------------

## destroy removes the token and its variables
check do
  Bone.destroy(@token)
  Bone.token?(@token) == false
end
#=> true

## Import loads dotenv text under a fresh token
check do
  @t2, @s2 = *Bone.generate
  @tokens << @t2
  Bone.credentials = "#{@t2}:#{@s2}"
  Bone.import("STAGING_URL=https://staging.example.com\nLOG_LEVEL=debug\n").sort == ['LOG_LEVEL', 'STAGING_URL']
end
#=> true

## Imported values are retrievable
check { Bone[:STAGING_URL] == 'https://staging.example.com' }
#=> true

# -- Teardown -------------------------------------------------------------
# Destroy every token this file created. Guarded by @redis_up (destroy would
# reconnect and raise when the server is down, turning a clean skip into an
# infrastructure failure) and wrapped so a mid-file failure can never leak a
# token; the ensure clears the accumulator regardless.
#
# A broken destroy would otherwise leave credentials in the selected DB with no
# signal. Attempt every token, then report leaks loudly on STDERR (fd 2, which
# Tryouts does not capture) rather than swallowing each error silently.
begin
  @teardown_failures = []
  if @redis_up
    @tokens.each do |t|
      Bone.destroy(t)
    rescue StandardError => e
      @teardown_failures << "#{t} (#{e.class}: #{e.message})"
    end
  end
ensure
  @tokens.clear
end
unless @teardown_failures.empty?
  STDERR.puts "# TEARDOWN: #{@teardown_failures.size} token(s) leaked in #{Bone.source}: #{@teardown_failures.join(', ')}"
end

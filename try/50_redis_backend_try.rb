# try/50_redis_backend_try.rb
#
# Exercises the Valkey/Redis (Familia v2) backend. Requires a running
# Valkey/Redis server. Point at it with BONE_SOURCE, e.g.
#
#   BONE_SOURCE=redis://127.0.0.1:6379/0 bundle exec try try/50_redis_backend_try.rb
#
# CI provides a valkey service and sets BONE_SOURCE automatically.

require 'bone'

Bone.source = ENV['BONE_SOURCE'] || 'redis://127.0.0.1:6379/0'

## Selects the redis backend
Bone.backend
#=> Bone::Backends::Redis

## The lazily-defined Token model is a Familia::Horreum
Bone::Backends::Redis.model.ancestors.include?(Familia::Horreum)
#=> true

## Can generate and register a token
@token, @secret = *Bone.generate
Bone.token?(@token)
#=> true

## Secret round-trips through the store
Bone.backend.secret(@token)
#=> @secret

## Set/get a value
Bone.credentials = "#{@token}:#{@secret}"
Bone[:api_key] = 'sk-test-123'
Bone[:api_key]
#=> 'sk-test-123'

## Non-string values are stored as strings
Bone[:replicas] = 3
Bone[:replicas]
#=> '3'

## key? reflects presence
Bone.key?(:api_key)
#=> true

## keys lists variable names
Bone.keys.sort
#=> ['api_key', 'replicas']

## env returns the full hash
Bone.env
#=> {'api_key' => 'sk-test-123', 'replicas' => '3'}

## delete removes a variable
Bone.delete(:replicas)
Bone.key?(:replicas)
#=> false

## destroy removes the token and its variables
Bone.destroy(@token)
Bone.token?(@token)
#=> false

## Teardown: register a fresh token used for import
@t2, @s2 = *Bone.generate
Bone.credentials = "#{@t2}:#{@s2}"
Bone.import("STAGING_URL=https://staging.example.com\nLOG_LEVEL=debug\n").sort
#=> ['LOG_LEVEL', 'STAGING_URL']

## Imported values are retrievable
Bone[:STAGING_URL]
#=> 'https://staging.example.com'

Bone.destroy(@t2)

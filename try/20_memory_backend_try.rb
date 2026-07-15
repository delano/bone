# try/20_memory_backend_try.rb

require 'bone'

Bone::Backends::Memory.reset!
Bone.source = 'memory://localhost'

## Selects the memory backend
Bone.backend
#=> Bone::Backends::Memory

## Can generate a token/secret pair
@token, @secret = *Bone.generate
[@token.class, @secret.class]
#=> [String, String]

## Generated token is registered
Bone.token?(@token)
#=> true

## Unknown token is not registered
Bone.token?('nope')
#=> false

## Can register an explicit token
Bone.register('atoken', 'asecret')
#=> 'atoken'

## Registering a duplicate raises
begin
  Bone.register('atoken', 'x')
  false
rescue Bone::TokenExists
  true
end
#=> true

## Secret round-trips
Bone.backend.secret('atoken')
#=> 'asecret'

## Set/get through the ambient client
Bone.credentials = 'atoken:asecret'
Bone[:database_url] = 'postgres://localhost/app'
Bone[:database_url]
#=> 'postgres://localhost/app'

## Values are coerced to strings
Bone[:port] = 5432
Bone[:port]
#=> '5432'

## key? reflects presence
Bone.key?(:port)
#=> true

## Missing key returns nil
Bone[:missing]
#=> nil

## keys lists names
Bone.keys.sort
#=> ['database_url', 'port']

## keys supports a glob filter
Bone[:database_pool] = '5'
Bone.keys('database_*').sort
#=> ['database_pool', 'database_url']

## delete removes a key
Bone.delete(:port)
Bone.key?(:port)
#=> false

## Destroy removes the token
Bone.destroy('atoken')
Bone.token?('atoken')
#=> false

# -- F4/F5: unknown-token read contract (must match the Redis backend) ----
# Reading through a token that is not in the store returns benign defaults;
# only WRITING to it raises. (Memory used to raise on these reads.)

## Unknown token in store: get returns nil (reads never raise)
@unknown = Bone::Client.new('no-such-token')
@unknown.get(:anything)
#=> nil

## Unknown token in store: keys returns empty
@unknown.keys
#=> []

## Unknown token in store: key? returns false
@unknown.key?(:anything)
#=> false

## Unknown token in store: to_h returns empty
@unknown.to_h
#=> {}

## Unknown token in store: delete returns false
@unknown.delete(:anything)
#=> false

## Unknown token in store: only set raises (NoToken)
begin
  @unknown.set(:anything, 'v')
  false
rescue Bone::NoToken
  true
end
#=> true

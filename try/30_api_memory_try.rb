# try try/30_api_redis_try.rb

require 'bone'
#Bone.debug = true
Bone.source = 'memory://localhost'

## Can set the base uri via ENV 
## (NOTE: must be set before the require)
Bone.source.to_s
#=> 'memory://localhost'

## Knows to use the redis API
Bone.api
#=> Bone::API::Memory

## Can generate a token
@generated_token, secret = *Bone.generate
@generated_token.size
#=> 24

## Can register a token
@token = Bone.register 'atoken', 'secret1'
@token
#=> 'atoken'

## Can check secret via API
Bone.api.secret 'atoken'
#=> 'secret1'

## Can set token directly
Bone.token = @token
Bone.token
#=> @token

## Knows a valid token
Bone.token? @token
#=> true

## Knows an invalid token
Bone.token? 'bogustoken'
#=> false

## Empty key returns nil
Bone['bogus']
#=> nil

## Make request to API directly
Bone.api.get Bone.token, Bone.secret, 'bogus'
#=> nil

## Set a value
Bone['valid'] = true
Bone['valid']
#=> 'true'

## Get a value
Bone['valid']
#=> 'true'

## Knows all keys
Bone.keys
#=> ["v2:bone:#{@token}:valid"]

## Knows when a key exists
Bone.key? :valid
#=> true

## Knows when a key doesn't exist
Bone.key? :bogus
#=> false

Bone.destroy @token
Bone.destroy @generated_token


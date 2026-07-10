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

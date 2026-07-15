# try/10_version_try.rb

require 'bone'

## Version is a dotted string
Bone::VERSION.to_s
#=> '0.4.0'

## Version exposes its parts
Bone::VERSION.to_a
#=> [0, 4, 0]

## Default source is Redis
Bone.source = 'memory://localhost'
Bone.source.scheme
#=> 'memory'

## random_token has the requested length
Bone.random_token(26).length
#=> 26

## random_token is alphanumeric
Bone.random_token(40).match?(/\A[A-Za-z0-9]+\z/)
#=> true

## two secrets differ
Bone.random_secret != Bone.random_secret
#=> true

# -- F9: backend selection --------------------------------------------------

## An unregistered scheme raises UnknownBackend (source= selects eagerly)
begin
  Bone.source = 'ftp://nope'
  false
rescue Bone::UnknownBackend
  true
end
#=> true

## A known scheme selects a backend without raising (restores clean state)
Bone.source = 'memory://localhost'
Bone.source.scheme
#=> 'memory'

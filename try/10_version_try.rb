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

# try try/32_api_http_try.rb

ENV['BONE_TOKEN'] = 'testtoken'
require 'bone'

#ENV['BONE_TOKEN'] = '1c397d204aa4e94f566d7f78cc4bb5bef5b558d9bd64c1d8a45e67a621fb87dc'

## Can set the base uri directly
Bone.source = "http://localhost:3073"
Bone.source.to_s
##=> "http://localhost:3073"

## Knows to use the redis HTTP
Bone.api
##=> Bone::API::HTTP

## Empty key returns nil
Bone['bogus']
##=> nil

## Make request to API directly
Bone::API.get 'bogus'
##=> nil
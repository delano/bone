# frozen_string_literal: true

require_relative 'lib/bone/version'

Gem::Specification.new do |spec|
  spec.name        = 'bone'
  spec.version     = Bone::VERSION.to_s
  spec.summary     = 'Remote environment variables over Valkey/Redis.'
  spec.description = 'Bone: a small client and CLI for storing and retrieving ' \
                     'remote environment variables, backed by Valkey/Redis (via ' \
                     'Familia) or an in-memory store.'
  spec.authors     = ['Delano Mandelbaum']
  spec.email       = 'gems@solutious.com'
  spec.homepage    = 'https://github.com/solutious/bone'
  spec.license     = 'MIT'

  spec.files = if File.directory?('.git') && system('git --version > /dev/null 2>&1')
                 `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|try)/}) }
               else
                 Dir['**/*'].select { |f| File.file?(f) }.reject { |f| f.match(%r{^(test|spec|try)/}) }
               end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = Gem::Requirement.new('>= 3.2')

  spec.add_dependency 'dry-cli', '~> 1.2'
  spec.add_dependency 'familia', '~> 2.11'
  spec.add_dependency 'base64'

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGES.txt"
end

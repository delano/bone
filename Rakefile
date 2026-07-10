# frozen_string_literal: true

# Bundler's standard gem tasks: build / install / release (and release:*).
# `bundle exec rake release` is what the release-gem.yml workflow invokes.
require 'bundler/gem_tasks'

desc 'Run the Tryouts test suite (ensures a UTF-8 locale)'
task :test do
  ENV['LANG'] ||= 'C.UTF-8'
  ENV['LC_ALL'] ||= 'C.UTF-8'
  sh 'bundle exec try -v try/'
end

desc 'Run RuboCop'
task :rubocop do
  sh 'bundle exec rubocop'
end

task default: :test

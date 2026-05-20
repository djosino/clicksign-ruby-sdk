# frozen_string_literal: true

require_relative 'lib/clicksign/version'

Gem::Specification.new do |spec|
  spec.name     = 'clicksign-ruby-sdk'
  spec.version  = Clicksign::VERSION
  spec.authors  = ['Clicksign']
  spec.summary     = 'Ruby SDK for the Clicksign API'
  spec.description = 'Official Ruby SDK for the Clicksign e-signature API (v3). ' \
                     'Supports envelope management, signing workflows and webhooks. ' \
                     'JSON:API compliant, no runtime dependencies beyond the Ruby stdlib.'
  spec.homepage = 'https://github.com/djosino/clicksign-ruby-sdk'
  spec.license  = 'MIT'

  spec.required_ruby_version = '>= 3.0'

  spec.files = Dir['lib/**/*.rb'] + ['README.md']
  spec.metadata['source_code_uri']    = spec.homepage
  spec.metadata['changelog_uri']      = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']    = "#{spec.homepage}/issues"
  spec.metadata['documentation_uri']  = spec.homepage
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
end

# frozen_string_literal: true

require_relative './lib/xero_exporter/version'

Gem::Specification.new do |s|
  s.name          = 'xero_exporter'
  s.description   = 'A library for exporting financial data to the Xero API.'
  s.summary       = s.description
  s.homepage      = 'https://github.com/krystal/xero_exporter'
  s.version       = XeroExporter::VERSION
  s.files         = Dir.glob('VERSION') + Dir.glob('{lib}/**/*')
  s.require_paths = ['lib']
  s.authors       = ['Adam Cooke']
  s.email         = ['adam@krystal.uk']
  s.add_runtime_dependency 'json'
  s.required_ruby_version = '>= 2.5'
end

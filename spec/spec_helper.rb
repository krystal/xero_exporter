# frozen_string_literal: true

SPEC_ROOT = __dir__
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'xero_exporter'

Dir[File.join(SPEC_ROOT, 'support', '**', '*.rb')].sort.each { |path| require path }

RSpec.configure do |config|
  config.color = true

  config.expect_with :rspec do |expectations|
    expectations.max_formatted_output_length = 1_000_000
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before do
    @logger_string_io = StringIO.new
    XeroExporter.logger = Logger.new(@logger_string_io)
  end

  config.include ExportHelpers
end

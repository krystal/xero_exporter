# frozen_string_literal: true

require 'spec_helper'
require 'xero_exporter/country'

describe XeroExporter::Country do
  subject(:country) { described_class.new('GB') }

  context '#name' do
    it 'returns the name' do
      expect(country.name).to eq 'United Kingdom'
    end
  end
end

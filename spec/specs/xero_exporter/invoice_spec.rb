# frozen_string_literal: true

require 'spec_helper'
require 'xero_exporter/invoice'

describe XeroExporter::Invoice do
  subject(:invoice) { described_class.new }

  context '#tax_rate' do
    it 'raises an error if both tax_rate_name and country are set' do
      invoice.tax_rate_name = 'Custom Tax'
      invoice.country = 'GB'
      invoice.tax_rate = 20.0
      expect { invoice.tax_rate }.to raise_error(XeroExporter::Error, 'tax_rate_name and country cannot both be set')
    end

    it 'includes the custom name when tax_rate_name is set' do
      invoice.tax_rate_name = 'Custom Tax'
      invoice.tax_rate = 20.0
      expect(invoice.tax_rate.name).to eq 'Custom Tax'
    end

    it 'does not include a name when only country is set' do
      invoice.country = 'GB'
      invoice.tax_rate = 20.0
      expect(invoice.tax_rate.name).to be_nil
    end
  end

  context '#add_line' do
    it 'adds a line' do
      line = invoice.add_line(account_code: '200', amount: 100, tax: 20)
      expect(line.account_code).to eq '200'
      expect(line.amount).to eq 100
      expect(line.tax).to eq 20
      expect(invoice.lines).to eq [line]
    end
  end
end

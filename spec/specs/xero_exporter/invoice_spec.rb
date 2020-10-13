# frozen_string_literal: true

require 'spec_helper'
require 'xero_exporter/invoice'

describe XeroExporter::Invoice do
  subject(:invoice) { described_class.new }

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

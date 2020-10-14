# frozen_string_literal: true

require 'spec_helper'
require 'date'
require 'xero_exporter/export'

describe XeroExporter::Export do
  subject(:export) { described_class.new }

  context '#reference' do
    it 'contains the currency' do
      export.date = Date.new(2020, 3, 12)
      export.currency = 'gbp'
      expect(export.reference).to eq '20200312-GBP-'
    end

    it 'contains the ID' do
      export.date = Date.new(2020, 3, 12)
      export.currency = 'gbp'
      export.id = 'someid'
      expect(export.reference).to eq '20200312-GBP-someid'
    end
  end

  context '#invoices' do
    it 'is an array of invoices' do
      expect(export.invoices).to be_a Array
    end
  end

  context '#add_invoice' do
    it 'adds a new invoice' do
      invoice = export.add_invoice do |i|
        i.id = 'example'
      end
      expect(invoice.id).to eq 'example'
      expect(export.invoices).to eq [invoice]
    end
  end

  context '#add_payment' do
    it 'adds a new payment' do
      payment = export.add_payment do |p|
        p.id = 'example'
      end
      expect(payment.id).to eq 'example'
      expect(export.payments).to eq [payment]
    end
  end

  context '#add_refund' do
    it 'adds a new refund' do
      refund = export.add_refund do |r|
        r.id = 'example'
      end
      expect(refund.id).to eq 'example'
      expect(export.refunds).to eq [refund]
    end
  end
end

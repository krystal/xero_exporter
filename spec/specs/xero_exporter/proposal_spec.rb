# frozen_string_literal: true

require 'spec_helper'
require 'xero_exporter/export'
require 'xero_exporter/proposal'
module XeroExporter

  RSpec.describe XeroExporter::Proposal do
    context '#invoice_lines' do
      context 'with an example set of data' do
        before do
          export = Export.new

          export.add_invoice do |invoice|
            invoice.country = 'GB'
            invoice.tax_rate = 20.0
            invoice.add_line account_code: '200', amount: 100.0, tax: 20.0
          end

          export.add_invoice do |invoice|
            invoice.country = 'GB'
            invoice.tax_rate = 20.0
            invoice.add_line account_code: '200', amount: 500.0, tax: 100.0
          end

          export.add_invoice do |invoice|
            invoice.country = 'GB'
            invoice.tax_rate = 20.0
            invoice.add_line account_code: '201', amount: 200.0, tax: 40.0
          end

          export.add_invoice do |invoice|
            invoice.country = 'FR'
            invoice.tax_rate = 21.0
            invoice.tax_type = :moss
            invoice.add_line account_code: '200', amount: 100.0, tax: 21.0
          end

          export.add_invoice do |invoice|
            invoice.country = 'US'
            invoice.tax_type = :none
            invoice.add_line account_code: '200', amount: 1000.0, tax: 0.0
          end

          @proposal = Proposal.new(export)
          @invoice_lines = @proposal.invoice_lines
        end

        it 'returns a hash grouped by account, country and tax' do
          expect(@invoice_lines[['200', Country.new('GB'), TaxRate.new(20.0, :normal)]][:amount]).to eq 600.0
          expect(@invoice_lines[['200', Country.new('GB'), TaxRate.new(20.0, :normal)]][:tax]).to eq 120.0

          expect(@invoice_lines[['201', Country.new('GB'), TaxRate.new(20.0, :normal)]][:amount]).to eq 200.0
          expect(@invoice_lines[['201', Country.new('GB'), TaxRate.new(20.0, :normal)]][:tax]).to eq 40.0

          expect(@invoice_lines[['200', Country.new('FR'), TaxRate.new(21.0, :moss)]][:amount]).to eq 100.0
          expect(@invoice_lines[['200', Country.new('FR'), TaxRate.new(21.0, :moss)]][:tax]).to eq 21.0

          expect(@invoice_lines[['200', Country.new('US'), TaxRate.new(nil, :none)]][:amount]).to eq 1000.0
          expect(@invoice_lines[['200', Country.new('US'), TaxRate.new(nil, :none)]][:tax]).to eq 0.0
        end
      end
    end

    context '#payments' do
      context 'with an example set of data' do
        before do
          export = Export.new
          export.add_payment do |p|
            p.amount = 10
            p.fees = 0.50
            p.bank_account = '010'
          end
          export.add_payment do |p|
            p.amount = 50
            p.fees = 2.0
            p.bank_account = '010'
          end
          export.add_payment do |p|
            p.amount = 10
            p.fees = 0.50
            p.bank_account = '020'
          end

          @proposal = Proposal.new(export)
          @payments = @proposal.payments
        end

        it 'returns a hash grouped by account, country and tax' do
          expect(@payments['010'][:amount]).to eq 60
          expect(@payments['010'][:fees]).to eq 2.5

          expect(@payments['020'][:amount]).to eq 10
          expect(@payments['020'][:fees]).to eq 0.50
        end
      end
    end

    context '#refunds' do
      context 'with an example set of data' do
        before do
          export = Export.new
          export.add_refund do |p|
            p.amount = 10
            p.fees = 0.50
            p.bank_account = '010'
          end
          export.add_refund do |p|
            p.amount = 50
            p.fees = 2.0
            p.bank_account = '010'
          end
          export.add_refund do |p|
            p.amount = 10
            p.fees = 0.50
            p.bank_account = '020'
          end

          @proposal = Proposal.new(export)
          @refunds = @proposal.refunds
        end

        it 'returns a hash grouped by account, country and tax' do
          expect(@refunds['010'][:amount]).to eq 60
          expect(@refunds['010'][:fees]).to eq 2.5

          expect(@refunds['020'][:amount]).to eq 10
          expect(@refunds['020'][:fees]).to eq 0.50
        end
      end
    end
  end

end

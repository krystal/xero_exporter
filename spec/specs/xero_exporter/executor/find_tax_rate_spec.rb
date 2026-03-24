# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context 'tax rate lookup' do
    it 'finds an existing tax rate by country name' do
      executor, state = create_executor do |e, api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        expect(api).to receive(:get).with('TaxRates').and_return({
          'TaxRates' => [
            { 'Name' => 'Tax for United Kingdom (20.0%)', 'Status' => 'ACTIVE', 'ReportTaxType' => 'OUTPUT',
              'EffectiveRate' => '20.0', 'TaxType' => 'TAX001' }
          ]
        })

        expect(api).to receive(:get).with('Contacts', anything).and_return({
          'Contacts' => [{ 'ContactID' => 'contact-1' }]
        })

        expect(api).to receive(:post).with('Invoices', anything) do |_, params|
          expect(params['LineItems'][0]['TaxType']).to eq 'TAX001'
          { 'Invoices' => [{ 'InvoiceID' => 'inv-1', 'AmountDue' => 120.0 }] }
        end
      end

      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
    end

    it 'finds an existing tax rate by country code' do
      executor, state = create_executor do |e, api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        expect(api).to receive(:get).with('TaxRates').and_return({
          'TaxRates' => [
            { 'Name' => 'Tax for GB (20.0%)', 'Status' => 'ACTIVE', 'ReportTaxType' => 'OUTPUT',
              'EffectiveRate' => '20.0', 'TaxType' => 'TAX002' }
          ]
        })

        expect(api).to receive(:get).with('Contacts', anything).and_return({
          'Contacts' => [{ 'ContactID' => 'contact-1' }]
        })

        expect(api).to receive(:post).with('Invoices', anything) do |_, params|
          expect(params['LineItems'][0]['TaxType']).to eq 'TAX002'
          { 'Invoices' => [{ 'InvoiceID' => 'inv-1', 'AmountDue' => 120.0 }] }
        end
      end

      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
    end

    it 'does not match an inactive tax rate' do
      executor, state = create_executor do |e, api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        expect(api).to receive(:get).with('TaxRates').and_return({
          'TaxRates' => [
            { 'Name' => 'Tax for GB (20.0%)', 'Status' => 'DELETED', 'ReportTaxType' => 'OUTPUT',
              'EffectiveRate' => '20.0', 'TaxType' => 'DELETED_TAX' }
          ]
        })

        # Should create a new tax rate since the existing one is inactive
        expect(api).to receive(:post).with('TaxRates', anything) do |_, params|
          { 'TaxRates' => [{ 'TaxType' => 'NEW_TAX' }] }
        end

        expect(api).to receive(:get).with('Contacts', anything).and_return({
          'Contacts' => [{ 'ContactID' => 'contact-1' }]
        })

        expect(api).to receive(:post).with('Invoices', anything) do |_, params|
          expect(params['LineItems'][0]['TaxType']).to eq 'NEW_TAX'
          { 'Invoices' => [{ 'InvoiceID' => 'inv-1', 'AmountDue' => 120.0 }] }
        end
      end

      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
    end

    it 'does not match a tax rate with a different effective rate' do
      executor, state = create_executor do |e, api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        expect(api).to receive(:get).with('TaxRates').and_return({
          'TaxRates' => [
            { 'Name' => 'Tax for GB (10.0%)', 'Status' => 'ACTIVE', 'ReportTaxType' => 'OUTPUT',
              'EffectiveRate' => '10.0', 'TaxType' => 'WRONG_RATE' }
          ]
        })

        expect(api).to receive(:post).with('TaxRates', anything) do |_, params|
          { 'TaxRates' => [{ 'TaxType' => 'CORRECT_TAX' }] }
        end

        expect(api).to receive(:get).with('Contacts', anything).and_return({
          'Contacts' => [{ 'ContactID' => 'contact-1' }]
        })

        expect(api).to receive(:post).with('Invoices', anything) do |_, params|
          expect(params['LineItems'][0]['TaxType']).to eq 'CORRECT_TAX'
          { 'Invoices' => [{ 'InvoiceID' => 'inv-1', 'AmountDue' => 120.0 }] }
        end
      end

      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
    end

    it 'caches tax rate lookups across multiple line items' do
      executor, state = create_executor do |e, api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '201', amount: 50, tax: 10
        end

        expect(api).to receive(:get).with('TaxRates').and_return({ 'TaxRates' => [] })

        # Should only create the tax rate once despite two lines with the same country/rate
        expect(api).to receive(:post).with('TaxRates', anything).once do |_, params|
          { 'TaxRates' => [{ 'TaxType' => 'CACHED_TAX' }] }
        end

        expect(api).to receive(:get).with('Contacts', anything).and_return({
          'Contacts' => [{ 'ContactID' => 'contact-1' }]
        })

        expect(api).to receive(:post).with('Invoices', anything) do |_, params|
          expect(params['LineItems'][0]['TaxType']).to eq 'CACHED_TAX'
          expect(params['LineItems'][1]['TaxType']).to eq 'CACHED_TAX'
          { 'Invoices' => [{ 'InvoiceID' => 'inv-1', 'AmountDue' => 180.0 }] }
        end
      end

      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context 'tracking options' do
    it 'includes tracking options on invoice line items' do
      executor, state = create_executor do |e, api|
        e.tracking['Department'] = 'Sales'
        e.tracking['Region'] = 'EMEA'

        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        expect(api).to receive(:get).with('TaxRates').and_return({ 'TaxRates' => [] })

        expect(api).to receive(:post).with('TaxRates', anything).and_return({
          'TaxRates' => [{ 'TaxType' => 'TAX001' }]
        })

        expect(api).to receive(:get).with('Contacts', anything).and_return({
          'Contacts' => [{ 'ContactID' => 'contact-1' }]
        })

        expect(api).to receive(:post).with('Invoices', anything) do |_, invoice_params|
          tracking = invoice_params['LineItems'][0]['Tracking']
          expect(tracking).to eq [
            { 'Name' => 'Department', 'Option' => 'Sales' },
            { 'Name' => 'Region', 'Option' => 'EMEA' }
          ]
          { 'Invoices' => [{ 'InvoiceID' => 'inv-1', 'AmountDue' => 120.0 }] }
        end
      end

      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
    end

    it 'includes empty tracking when no tracking is configured' do
      executor, state = create_executor do |e, api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        expect(api).to receive(:get).with('TaxRates').and_return({ 'TaxRates' => [] })

        expect(api).to receive(:post).with('TaxRates', anything).and_return({
          'TaxRates' => [{ 'TaxType' => 'TAX001' }]
        })

        expect(api).to receive(:get).with('Contacts', anything).and_return({
          'Contacts' => [{ 'ContactID' => 'contact-1' }]
        })

        expect(api).to receive(:post).with('Invoices', anything) do |_, invoice_params|
          expect(invoice_params['LineItems'][0]['Tracking']).to eq []
          { 'Invoices' => [{ 'InvoiceID' => 'inv-1', 'AmountDue' => 120.0 }] }
        end
      end

      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
    end
  end
end

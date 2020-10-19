# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context '#create_invoice' do
    it 'should create an invoice if there are lines for one' do
      executor, state = create_executor do |e, api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        e.add_invoice do |invoice|
          invoice.country = 'DE'
          invoice.tax_rate = 21.0
          invoice.tax_type = :moss
          invoice.add_line account_code: '200', amount: 100, tax: 21
        end

        e.add_invoice do |invoice|
          invoice.country = 'US'
          invoice.tax_type = :none
          invoice.add_line account_code: '205', amount: 250
        end

        # We expect to get the list of tax rates, we're going to assume there are no
        # existing tax rates at this point.
        expect(api).to receive(:get).with('TaxRates').and_return({ 'TaxRates' => [] })

        # We'll expect that we need to create a tax rate for each applicable tax.
        expect(api).to receive(:post).with('TaxRates', anything).at_least(:once) do |_, params|
          {
            'TaxRates' => [{ 'TaxType' => params['Name'] }]
          }
        end

        # We'll want to get the ID for the contact so we'll return a contact
        # in this result.
        expect(api).to receive(:get).with('Contacts', anything).and_return({
          'Contacts' => [{ 'ContactID' => 'abcdef' }]
        })

        # We'll expect that the invoice will be posted to the Xero API.
        expect(api).to receive(:post).with('Invoices', anything) do |_, params|
          expect(params.dig('Contact', 'ContactID')).to eq 'abcdef'

          expect(params['Date']).to eq '2020-10-02'
          expect(params['DueDate']).to eq '2020-10-02'
          expect(params['Reference']).to eq '20201002-GBP-1234'
          expect(params['CurrencyCode']).to eq 'GBP'
          expect(params['Status']).to eq 'AUTHORISED'

          expect(params['LineItems'].count).to eq 3

          expect(params['LineItems'][0]['AccountCode']).to eq '200'
          expect(params['LineItems'][0]['Quantity']).to eq 1
          expect(params['LineItems'][0]['TaxAmount']).to eq 20.0
          expect(params['LineItems'][0]['Description']).to eq 'Widgets (GB, 20.0%)'
          expect(params['LineItems'][0]['LineAmount']).to eq 100.0
          expect(params['LineItems'][0]['TaxType']).to eq 'Tax for GB (20.0%)'

          expect(params['LineItems'][1]['AccountCode']).to eq '200'
          expect(params['LineItems'][1]['Quantity']).to eq 1
          expect(params['LineItems'][1]['TaxAmount']).to eq 21.0
          expect(params['LineItems'][1]['Description']).to eq 'Widgets (DE, 21.0%)'
          expect(params['LineItems'][1]['LineAmount']).to eq 100.0
          expect(params['LineItems'][1]['TaxType']).to eq 'MOSS Germany 21.0%'

          expect(params['LineItems'][2]['AccountCode']).to eq '205'
          expect(params['LineItems'][2]['Quantity']).to eq 1
          expect(params['LineItems'][2]['TaxAmount']).to eq 0.0
          expect(params['LineItems'][2]['Description']).to eq '205 Sales (US, 0.0%)'
          expect(params['LineItems'][2]['LineAmount']).to eq 250.0
          expect(params['LineItems'][2]['TaxType']).to eq 'Tax for US (0.0%)'

          # Return our new invoice object
          {
            'Invoices' => [{
              'InvoiceID' => 'abcdef',
              'AmountDue' => params['LineItems'].sum { |li| li['TaxAmount'] + li['LineAmount'] }
            }]
          }
        end
      end

      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
      expect(state[:create_invoice][:invoice_id]).to eq 'abcdef'
      expect(state[:create_invoice][:amount]).to eq 491.0

      expect(@logger_string_io.string).to include 'Running create_invoice task'
      expect(@logger_string_io.string).to include 'Creating new invoice'
      expect(@logger_string_io.string).to include 'Found existing contact with name: Example Customer'
      expect(@logger_string_io.string).to include 'Invoice created with ID abcdef for 491.0'
    end

    it 'should not create an invoice if there are no lines' do
      executor, state = create_executor
      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
      expect(state[:create_invoice][:invoice_id]).to be nil
      expect(state[:create_invoice][:amount]).to be nil

      expect(@logger_string_io.string).to include 'Running create_invoice task'
      expect(@logger_string_io.string).to include 'Not creating an invoice because there are no invoice lines'
    end
  end
end

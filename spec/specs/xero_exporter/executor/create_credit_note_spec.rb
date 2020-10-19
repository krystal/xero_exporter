# frozen_string_literal: true

require 'date'
require 'spec_helper'

describe XeroExporter::Executor do
  context '#create_credit_note' do
    it 'should create a credit note if there are lines for one' do
      executor, state = create_executor do |e, api|
        e.add_credit_note do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        e.add_credit_note do |invoice|
          invoice.country = 'FR'
          invoice.tax_rate = 21.0
          invoice.tax_type = :moss
          invoice.add_line account_code: '200', amount: 100, tax: 21
        end

        e.add_credit_note do |invoice|
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
        expect(api).to receive(:post).with('CreditNotes', anything) do |_, params|
          expect(params.dig('Contact', 'ContactID')).to eq 'abcdef'

          expect(params['Date']).to eq '2020-10-02'
          expect(params['Reference']).to eq '20201002-GBP-1234'
          expect(params['CurrencyCode']).to eq 'GBP'
          expect(params['Status']).to eq 'AUTHORISED'

          expect(params['LineItems'].count).to eq 3

          expect(params['LineItems'][0]['AccountCode']).to eq '200'
          expect(params['LineItems'][0]['Quantity']).to eq 1
          expect(params['LineItems'][0]['TaxAmount']).to eq 20.0
          expect(params['LineItems'][0]['LineAmount']).to eq 100.0
          expect(params['LineItems'][0]['TaxType']).to eq 'Tax for GB (20.0%)'

          expect(params['LineItems'][1]['AccountCode']).to eq '200'
          expect(params['LineItems'][1]['Quantity']).to eq 1
          expect(params['LineItems'][1]['TaxAmount']).to eq 21.0
          expect(params['LineItems'][1]['LineAmount']).to eq 100.0
          expect(params['LineItems'][1]['TaxType']).to eq 'MOSS France 21.0%'

          expect(params['LineItems'][2]['AccountCode']).to eq '205'
          expect(params['LineItems'][2]['Quantity']).to eq 1
          expect(params['LineItems'][2]['TaxAmount']).to eq 0.0
          expect(params['LineItems'][2]['LineAmount']).to eq 250.0
          expect(params['LineItems'][2]['TaxType']).to eq 'Tax for US (0.0%)'

          # Return our new invoice object
          {
            'CreditNotes' => [{
              'CreditNoteID' => 'xyz',
              'RemainingCredit' => params['LineItems'].sum { |li| li['TaxAmount'] + li['LineAmount'] }
            }]
          }
        end
      end

      executor.create_credit_note
      expect(state[:create_credit_note][:state]).to eq 'complete'
      expect(state[:create_credit_note][:credit_note_id]).to eq 'xyz'
      expect(state[:create_credit_note][:amount]).to eq 491.0

      expect(@logger_string_io.string).to include 'Running create_credit_note task'
      expect(@logger_string_io.string).to include 'Creating new credit note'
      expect(@logger_string_io.string).to include 'Found existing contact with name: Example Customer'
      expect(@logger_string_io.string).to include 'Credit note created with ID xyz for 491.0'
    end

    it 'should not create an invoice if there are no lines' do
      executor, state = create_executor
      executor.create_credit_note
      expect(state[:create_credit_note][:state]).to eq 'complete'
      expect(state[:create_credit_note][:invoice_id]).to be nil
      expect(state[:create_credit_note][:amount]).to be nil

      expect(@logger_string_io.string).to include 'Running create_credit_note task'
      expect(@logger_string_io.string).to include 'Not creating a credit note because there are no lines'
    end
  end
end

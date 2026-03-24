# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context '#execute_all' do
    it 'executes all tasks in order' do
      executor, state = create_executor do |e, api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        e.add_payment do |payment|
          payment.amount = 120
          payment.bank_account = '010'
        end

        e.add_fee do |fee|
          fee.amount = 2.50
          fee.category = 'Bank Fees'
          fee.bank_account = '010'
        end

        expect(api).to receive(:get).with('TaxRates').and_return({ 'TaxRates' => [] })

        expect(api).to receive(:post).with('TaxRates', anything) do |_, tax_params|
          { 'TaxRates' => [{ 'TaxType' => tax_params['Name'] }] }
        end

        expect(api).to receive(:get).with('Contacts', anything).at_least(:once).and_return({
          'Contacts' => [{ 'ContactID' => 'contact-1' }]
        })

        expect(api).to receive(:post).with('Invoices', anything).and_return({
          'Invoices' => [{
            'InvoiceID' => 'inv-1',
            'AmountDue' => 120.0
          }]
        })

        expect(api).to receive(:put).with('Payments', anything).and_return({
          'Payments' => [{
            'PaymentID' => 'pay-1',
            'Amount' => 120.0
          }]
        })

        expect(api).to receive(:put).with('BankTransfers', anything) do |_, transfer_params|
          {
            'BankTransfers' => [{
              'BankTransferID' => 'transfer-1',
              'Amount' => transfer_params['Amount']
            }]
          }
        end

        expect(api).to receive(:post).with('BankTransactions', anything).and_return({
          'BankTransactions' => [{
            'BankTransactionID' => 'fee-1'
          }]
        })
      end

      result = executor.execute_all
      expect(result).to be true

      expect(state[:create_invoice][:state]).to eq 'complete'
      expect(state[:create_invoice][:invoice_id]).to eq 'inv-1'
      expect(state[:create_invoice_payment][:state]).to eq 'complete'
      expect(state[:create_credit_note][:state]).to eq 'complete'
      expect(state[:create_credit_note_payment][:state]).to eq 'complete'
      expect(state[:add_payments_010][:state]).to eq 'complete'
      expect(state[:add_fees_010_bank_fees][:state]).to eq 'complete'
    end

    it 'returns true when there is nothing to do' do
      executor, _state = create_executor
      result = executor.execute_all
      expect(result).to be true
    end
  end
end

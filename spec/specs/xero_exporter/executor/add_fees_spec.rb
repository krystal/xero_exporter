# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context '#add_fees' do
    it 'should create bank transactions' do
      executor, state = create_executor do |e, api|
        e.add_fee do |fee|
          fee.amount = 1.50
          fee.category = 'Bank Fees'
          fee.bank_account = '010'
        end

        e.add_fee do |fee|
          fee.amount = 5.0
          fee.category = 'Fraud Fees'
          fee.bank_account = '010'
        end

        e.add_fee do |fee|
          fee.amount = 1.50
          fee.category = 'Bank Fees'
          fee.bank_account = '011'
        end

        # We'll want to get the ID for the contact so we'll return a contact
        # in this result.
        expect(api).to receive(:get).with('Contacts', anything).at_least(:once) do |_, params|
          case params[:where]
          when /Stripe/
            { 'Contacts' => [{ 'ContactID' => 'stripe' }] }
          when /Generic/
            { 'Contacts' => [{ 'ContactID' => 'generic' }] }
          else
            { 'Contacts' => [{ 'ContactID' => 'other' }] }
          end
        end

        # We'll expect that the invoice will be posted to the Xero API.
        invoked_times = 0
        expect(api).to receive(:post).with('BankTransactions', anything).exactly(3).times do |_, params|
          expect(params['Date']).to eq '2020-10-02'
          expect(params['Type']).to eq 'SPEND'
          case invoked_times
          when 0
            expect(params['BankAccount']['Code']).to eq '010'
            expect(params['Contact']['ContactID']).to eq 'stripe'
            expect(params['LineItems'][0]['Description']).to eq 'Bank Fees'
            expect(params['LineItems'][0]['UnitAmount']).to eq 1.5
            expect(params['LineItems'][0]['AccountCode']).to eq '010.404'
          when 1
            expect(params['BankAccount']['Code']).to eq '010'
            expect(params['Contact']['ContactID']).to eq 'stripe'
            expect(params['LineItems'][0]['Description']).to eq 'Fraud Fees'
            expect(params['LineItems'][0]['UnitAmount']).to eq 5.0
            expect(params['LineItems'][0]['AccountCode']).to eq '010.404'
          when 2
            expect(params['BankAccount']['Code']).to eq '011'
            expect(params['Contact']['ContactID']).to eq 'generic'
            expect(params['LineItems'][0]['Description']).to eq 'Bank Fees'
            expect(params['LineItems'][0]['UnitAmount']).to eq 1.5
            expect(params['LineItems'][0]['AccountCode']).to eq '404'
          end
          invoked_times += 1
          {
            'BankTransactions' => [{
              'BankTransactionID' =>
                "transaction-for-#{params['BankAccount']['Code']}-#{params['LineItems'][0]['Description']}"
            }]
          }
        end
      end

      executor.add_fees
      expect(state[:add_fees_010_bank_fees][:state]).to eq 'complete'
      expect(state[:add_fees_010_bank_fees][:transaction_id]).to eq 'transaction-for-010-Bank Fees'

      expect(state[:add_fees_010_fraud_fees][:state]).to eq 'complete'
      expect(state[:add_fees_010_fraud_fees][:transaction_id]).to eq 'transaction-for-010-Fraud Fees'

      expect(state[:add_fees_011_bank_fees][:state]).to eq 'complete'
      expect(state[:add_fees_011_bank_fees][:transaction_id]).to eq 'transaction-for-011-Bank Fees'

      expect(@logger_string_io.string).to include 'Running add_fees_010_bank_fees task'
      expect(@logger_string_io.string).to include 'Running add_fees_010_fraud_fees task'
      expect(@logger_string_io.string).to include 'Running add_fees_011_bank_fees task'
      expect(@logger_string_io.string).to include 'Creating fee transaction for 1.5 from 010 (Bank Fees)'
      expect(@logger_string_io.string).to include 'Creating fee transaction for 5.0 from 010 (Fraud Fees)'
      expect(@logger_string_io.string).to include 'Creating fee transaction for 1.5 from 011 (Bank Fees)'
    end

    it "won't run when there are no payments" do
      executor, state = create_executor
      executor.add_payments
      expect(state).to be_empty
    end
  end
end

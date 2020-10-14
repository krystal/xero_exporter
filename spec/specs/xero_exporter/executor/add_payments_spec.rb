# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context '#add_payments' do
    it 'should create an invoice if there are lines for one' do
      executor, state = create_executor do |e, api|
        e.add_payment do |payment|
          payment.amount = 100
          payment.bank_account = '010'
          payment.fees = 1.25
        end

        e.add_payment do |payment|
          payment.amount = 250
          payment.bank_account = '011'
          payment.fees = 5.99
        end

        e.add_payment do |payment|
          payment.amount = 0
          payment.bank_account = '012'
          payment.fees = -2.50
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
        expect(api).to receive(:put).with('BankTransfers', anything).exactly(3).times do |_, params|
          expect(params['Date']).to eq '2020-10-02'
          expect(params['FromBankAccount']['Code']).to eq e.receivables_account
          case invoked_times
          when 0
            expect(params['Amount']).to eq 100.0
            expect(params['ToBankAccount']['Code']).to eq '010'
          when 1
            expect(params['Amount']).to eq 250.0
            expect(params['ToBankAccount']['Code']).to eq '011'
          when 2
            expect(params['Amount']).to eq 0.0
            expect(params['ToBankAccount']['Code']).to eq '012'
          end
          invoked_times += 1
          {
            'BankTransfers' => [{
              'BankTransferID' => "transferid-for-#{params['ToBankAccount']['Code']}",
              'Amount' => params['Amount']
            }]
          }
        end

        invoked_times2 = 0
        expect(api).to receive(:post).with('BankTransactions', anything).exactly(3).times do |_, params|
          case invoked_times2
          when 0
            expect(params['Type']).to eq 'SPEND'
            expect(params['BankAccount']['Code']).to eq '010'
            expect(params['LineItems'][0]['UnitAmount']).to eq 1.25
            expect(params['LineItems'][0]['AccountCode']).to eq '010.404'
            expect(params['Contact']['ContactID']).to eq 'stripe'
          when 1
            expect(params['Type']).to eq 'SPEND'
            expect(params['BankAccount']['Code']).to eq '011'
            expect(params['LineItems'][0]['UnitAmount']).to eq 5.99
            expect(params['LineItems'][0]['AccountCode']).to eq '404'
            expect(params['Contact']['ContactID']).to eq 'generic'
          when 2
            expect(params['Type']).to eq 'RECEIVE'
            expect(params['BankAccount']['Code']).to eq '012'
            expect(params['LineItems'][0]['UnitAmount']).to eq 2.50
            expect(params['LineItems'][0]['AccountCode']).to eq '404'
            expect(params['Contact']['ContactID']).to eq 'generic'
          end
          invoked_times2 += 1
          {
            'BankTransactions' => [
              {
                'BankTransactionID' => "transid-for-#{params['BankAccount']['Code']}"
              }
            ]
          }
        end
      end

      executor.add_payments
      %w[010 011 012].each do |id|
        expect(state["add_payments_#{id}_transfer".to_sym][:state]).to eq 'complete'
        expect(state["add_payments_#{id}_transfer".to_sym][:transfer_id]).to eq "transferid-for-#{id}"
        expect(state["add_payments_#{id}_fee".to_sym][:state]).to eq 'complete'
        expect(state["add_payments_#{id}_fee".to_sym][:fee_transaction_id]).to eq "transid-for-#{id}"

        expect(@logger_string_io.string).to include "Running add_payments_#{id}_transfer task"
        expect(@logger_string_io.string).to include "Running add_payments_#{id}_fee task"
      end

      expect(@logger_string_io.string).to include 'Transferring 100.0 from 020 to 010'
      expect(@logger_string_io.string).to include 'Transferring 250.0 from 020 to 011'
      expect(@logger_string_io.string).to include 'Transferring 0.0 from 020 to 012'
    end

    it "won't run when there are no payments" do
      executor, state = create_executor
      executor.add_payments
      expect(state).to be_empty
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context '#add_refunds' do
    it 'should create refunds' do
      executor, state = create_executor do |e, api|
        e.add_refund do |refund|
          refund.amount = 100
          refund.bank_account = '010'
          refund.fees = 1.25
        end

        e.add_refund do |refund|
          refund.amount = 250
          refund.bank_account = '011'
          refund.fees = 5.99
        end

        e.add_refund do |refund|
          refund.amount = 0
          refund.bank_account = '012'
          refund.fees = -2.50
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
          expect(params['ToBankAccount']['Code']).to eq e.receivables_account
          case invoked_times
          when 0
            expect(params['Amount']).to eq 100.0
            expect(params['FromBankAccount']['Code']).to eq '010'
          when 1
            expect(params['Amount']).to eq 250.0
            expect(params['FromBankAccount']['Code']).to eq '011'
          when 2
            expect(params['Amount']).to eq 0.0
            expect(params['FromBankAccount']['Code']).to eq '012'
          end
          invoked_times += 1
          {
            'BankTransfers' => [{
              'BankTransferID' => "transferid-for-#{params['FromBankAccount']['Code']}",
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

      executor.add_refunds
      %w[010 011 012].each do |id|
        expect(state["add_refunds_#{id}_transfer".to_sym][:state]).to eq 'complete'
        expect(state["add_refunds_#{id}_transfer".to_sym][:transfer_id]).to eq "transferid-for-#{id}"
        expect(state["add_refunds_#{id}_fee".to_sym][:state]).to eq 'complete'
        expect(state["add_refunds_#{id}_fee".to_sym][:fee_transaction_id]).to eq "transid-for-#{id}"

        expect(@logger_string_io.string).to include "Running add_refunds_#{id}_transfer task"
        expect(@logger_string_io.string).to include "Running add_refunds_#{id}_fee task"
      end

      expect(@logger_string_io.string).to include 'Transferring 100.0 from 010 to 020'
      expect(@logger_string_io.string).to include 'Transferring 250.0 from 011 to 020'
      expect(@logger_string_io.string).to include 'Transferring 0.0 from 012 to 020'
    end

    it "won't run when there are no refunds" do
      executor, state = create_executor
      executor.add_refunds
      expect(state).to be_empty
    end
  end
end

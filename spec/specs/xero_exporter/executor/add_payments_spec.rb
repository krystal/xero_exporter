# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context '#add_payments' do
    it 'should create an invoice if there are lines for one' do
      executor, state = create_executor do |e, api|
        e.add_payment do |payment|
          payment.amount = 100
          payment.bank_account = '010'
        end

        e.add_payment do |payment|
          payment.amount = 250
          payment.bank_account = '011'
        end

        e.add_payment do |payment|
          payment.amount = 0
          payment.bank_account = '012'
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
      end

      executor.add_payments
      %w[010 011 012].each do |id|
        expect(state["add_payments_#{id}".to_sym][:state]).to eq 'complete'
        expect(state["add_payments_#{id}".to_sym][:transfer_id]).to eq "transferid-for-#{id}"

        expect(@logger_string_io.string).to include "Running add_payments_#{id} task"
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

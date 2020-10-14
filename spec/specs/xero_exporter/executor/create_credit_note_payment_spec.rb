# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context '#create_credit_note_payment' do
    it 'should create an credit_note if there are lines for one' do
      initial_state = {
        create_credit_note: {
          state: 'complete',
          credit_note_id: 'xyz',
          amount: 500.0
        }
      }

      executor, state = create_executor(initial_state: initial_state) do |e, api|
        expect(api).to receive(:put).with('Payments', anything) do |_, params|
          expect(params.dig('Account', 'Code')).to eq e.receivables_account
          expect(params.dig('CreditNote', 'CreditNoteID')).to eq 'xyz'
          expect(params['Amount']).to eq 500.0
          expect(params['Reference']).to eq e.reference

          {
            'Payments' => [{
              'PaymentID' => 'payment-id-4444',
              'Amount' => 500.00
            }]
          }
        end
      end

      executor.create_credit_note_payment
      expect(state[:create_credit_note_payment][:state]).to eq 'complete'
      expect(state[:create_credit_note_payment][:payment_id]).to eq 'payment-id-4444'
      expect(state[:create_credit_note_payment][:amount]).to eq 500.0

      expect(@logger_string_io.string).to include 'Running create_credit_note_payment task'
      expect(@logger_string_io.string).to include 'Creating payment for credit note xyz for 500.0'
      expect(@logger_string_io.string).to include 'Using receivables account: 020'
    end

    it 'should not create an payment if there are no lines' do
      initial_state = {
        create_credit_note: {
          state: 'complete'
        }
      }

      executor, state = create_executor(initial_state: initial_state)
      executor.create_credit_note_payment
      expect(state[:create_credit_note_payment][:state]).to eq 'complete'
      expect(state[:create_credit_note_payment][:payment_id]).to be nil
      expect(state[:create_credit_note_payment][:amount]).to be nil

      expect(@logger_string_io.string).to include 'Running create_credit_note_payment task'
      expect(@logger_string_io.string).to include 'Not adding a payment because the amount ' \
                                                  'is not present or not positive'
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context '#create_invoice_payment' do
    it 'should create an invoice if there are lines for one' do
      initial_state = {
        create_invoice: {
          state: 'complete',
          invoice_id: 'abcdef',
          amount: 500.0
        }
      }

      executor, state = create_executor(initial_state: initial_state) do |e, api|
        expect(api).to receive(:put).with('Payments', anything) do |path, params|
          expect(params.dig('Account', 'Code')).to eq e.receivables_account
          expect(params.dig('Invoice', 'InvoiceID')).to eq 'abcdef'
          expect(params.dig('Amount')).to eq 500.0
          expect(params.dig('Reference')).to eq e.reference

          {
            'Payments' => [{
              'PaymentID' => 'payment-id-1234',
              'Amount' => 491.00
            }]
          }
        end
      end

      executor.create_invoice_payment
      expect(state[:create_invoice_payment][:state]).to eq 'complete'
      expect(state[:create_invoice_payment][:payment_id]).to eq 'payment-id-1234'
      expect(state[:create_invoice_payment][:amount]).to eq 491.0

      expect(@logger_string_io.string).to include 'Running create_invoice_payment task'
      expect(@logger_string_io.string).to include 'Creating payment for invoice abcdef for 500.0'
      expect(@logger_string_io.string).to include 'Using receivables account: 020'
    end

    it 'should not create an invoice if there are no lines' do
      initial_state = {
        create_invoice: {
          state: 'complete'
        }
      }

      executor, state = create_executor(initial_state: initial_state)
      executor.create_invoice_payment
      expect(state[:create_invoice_payment][:state]).to eq 'complete'
      expect(state[:create_invoice_payment][:payment_id]).to be nil
      expect(state[:create_invoice_payment][:amount]).to be nil

      expect(@logger_string_io.string).to include 'Running create_invoice_payment task'
      expect(@logger_string_io.string).to include 'Not adding a payment because the amount is not present or not positive'
    end
  end
end

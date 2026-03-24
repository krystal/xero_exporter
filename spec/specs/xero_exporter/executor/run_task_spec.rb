# frozen_string_literal: true

require 'spec_helper'

describe XeroExporter::Executor do
  context 'run_task state management' do
    it 'skips tasks that have already completed' do
      initial_state = {
        create_invoice: { state: 'complete', invoice_id: 'existing-inv' }
      }

      executor, state = create_executor(initial_state: initial_state) do |e, _api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end
      end

      executor.create_invoice

      # Should not have overwritten the existing state
      expect(state[:create_invoice][:invoice_id]).to eq 'existing-inv'
      expect(@logger_string_io.string).to include 'Not executing create_invoice because it has already been run'
    end

    it 'records error state when a task fails' do
      executor, state = create_executor do |e, api|
        e.add_invoice do |invoice|
          invoice.country = 'GB'
          invoice.tax_rate = 20.0
          invoice.add_line account_code: '200', amount: 100, tax: 20
        end

        expect(api).to receive(:get).with('TaxRates').and_raise(StandardError, 'API connection failed')
      end

      expect { executor.create_invoice }.to raise_error(StandardError, 'API connection failed')
      expect(state[:create_invoice][:state]).to eq 'error'
      expect(state[:create_invoice][:error][:class]).to eq 'StandardError'
      expect(state[:create_invoice][:error][:message]).to eq 'API connection failed'
    end

    it 'can retry a task that previously errored' do
      initial_state = {
        create_invoice: {
          state: 'error',
          error: { class: 'StandardError', message: 'previous failure' }
        }
      }

      executor, state = create_executor(initial_state: initial_state) do |_e, api|
        # No invoice lines, so it will complete with "not required"
      end

      executor.create_invoice
      expect(state[:create_invoice][:state]).to eq 'complete'
      expect(state[:create_invoice][:error]).to be_nil
    end
  end
end

# frozen_string_literal: true

require 'yaml'
require 'xero_exporter/proposal'
require 'bigdecimal'
require 'bigdecimal/util'

module XeroExporter
  class Executor

    attr_accessor :state_reader
    attr_accessor :state_writer

    def initialize(export, api, **options)
      @export = export
      @api = api
      @logger = options[:logger]
      @proposal = Proposal.new(export)
    end

    # Execute all actions required to perform this export
    #
    # @return [void]
    def execute_all
      create_invoice
      create_invoice_payment
      create_credit_note
      create_credit_note_payment
      add_payments
      add_refunds
      true
    end

    # Create an invoice for all invoice lines in the export
    #
    # @return [void]
    def create_invoice
      run_task :create_invoice do
        line_items = create_xero_line_items(@proposal.invoice_lines)
        if line_items.empty?
          logger.debug 'Not creating an invoice because there are no invoice lines'
          current_state[:status] = 'not required because no invoice lines'
          return false
        end

        logger.debug 'Creating new invoice'

        spec = {
          'Type' => 'ACCREC',
          'Contact' => {
            'ContactID' => find_or_create_xero_contact(@export.invoice_contact_name)
          },
          'Date' => @export.date.strftime('%Y-%m-%d'),
          'DueDate' => @export.date.strftime('%Y-%m-%d'),
          'Reference' => @export.reference,
          'CurrencyCode' => @export.currency,
          'Status' => 'AUTHORISED',
          'LineItems' => line_items
        }

        invoice = @api.post('Invoices', spec)['Invoices'].first

        logger.debug "Invoice created with ID #{invoice['InvoiceID']} for #{invoice['AmountDue']}"
        current_state[:status] = 'invoice created'
        current_state[:invoice_id] = invoice['InvoiceID']
        current_state[:amount] = invoice['AmountDue']
      end
    end

    # Create a credit note for all credit note lines in the export
    #
    # @return [void]
    def create_credit_note
      run_task :create_credit_note do
        line_items = create_xero_line_items(@proposal.credit_note_lines)
        if line_items.empty?
          logger.debug 'Not creating a credit note because there are no lines'
          current_state[:status] = 'not required because no credit note lines'
          return false
        end

        logger.debug 'Creating new credit note'
        spec = {
          'Type' => 'ACCRECCREDIT',
          'Contact' => {
            'ContactID' => find_or_create_xero_contact(@export.invoice_contact_name)
          },
          'Date' => @export.date.strftime('%Y-%m-%d'),
          'Reference' => @export.reference,
          'CurrencyCode' => @export.currency,
          'Status' => 'AUTHORISED',
          'LineItems' => line_items
        }

        credit_note = @api.post('CreditNotes', spec)['CreditNotes'].first

        logger.debug "Credit note created with ID #{credit_note['CreditNoteID']} for #{credit_note['RemainingCredit']}"
        current_state[:credit_note_id] = credit_note['CreditNoteID']
        current_state[:amount] = credit_note['RemainingCredit']
      end
    end

    # Create payments for all payments in the export
    #
    # @return [void]
    def add_payments
      @proposal.payments.each do |bank_account, amounts|
        run_task "add_payments_#{bank_account}_transfer" do
          transfer = add_bank_transfer(@export.receivables_account, bank_account, amounts[:amount])
          current_state[:transfer_id] = transfer['BankTransferID']
        end

        run_task "add_payments_#{bank_account}_fee" do
          if fee = add_fee_transaction(bank_account, amounts[:fees])
            current_state[:fee_transaction_id] = fee['BankTransactionID']
          end
        end
      end
    end

    # Create refunds for all payments in the export
    #
    # @return [void]
    def add_refunds
      @proposal.refunds.each do |bank_account, amounts|
        run_task "add_refunds_#{bank_account}_transfer" do
          transfer = add_bank_transfer(bank_account, @export.receivables_account, amounts[:amount])
          current_state[:transfer_id] = transfer['BankTransferID']
        end

        run_task "add_refunds_#{bank_account}_fee" do
          if fee = add_fee_transaction(bank_account, amounts[:fees])
            current_state[:fee_transaction_id] = fee['BankTransactionID']
          end
        end
      end
    end

    # Create a new payment that fully pays the given invoice
    #
    # @param invoice [Hash]
    # @return [void]
    def create_invoice_payment
      run_task :create_invoice_payment do
        if state[:create_invoice].nil?
          raise Error, 'create_invoice task must be executed before this action'
        end

        if state[:create_invoice][:amount].nil? || !state[:create_invoice][:amount].positive?
          logger.debug 'Not adding a payment because the amount is not present or not positive'
          return
        end

        logger.debug "Creating payment for invoice #{state[:create_invoice][:invoice_id]} " \
                        "for #{state[:create_invoice][:amount]}"
        logger.debug "Using receivables account: #{@export.receivables_account}"

        payment = @api.put('Payments', {
          'Invoice' => { 'InvoiceID' => state[:create_invoice][:invoice_id] },
          'Account' => { 'Code' => @export.receivables_account },
          'Date' => @export.date.strftime('%Y-%m-%d'),
          'Amount' => state[:create_invoice][:amount],
          'Reference' => @export.reference
        })['Payments'].first

        current_state[:payment_id] = payment['PaymentID']
        current_state[:amount] = payment['Amount']
      end
    end

    # Create a new payment that fully pays a given credit note
    #
    # @param credit_note [Hash]
    # @return [void]
    def create_credit_note_payment
      run_task :create_credit_note_payment do
        if state[:create_credit_note].nil?
          raise Error, 'create_credit_note task must be executed before this action'
        end

        if state[:create_credit_note][:amount].nil? || !state[:create_credit_note][:amount].positive?
          logger.debug 'Not adding a payment because the amount is not present or not positive'
          return
        end

        logger.debug "Creating payment for credit note #{state[:create_credit_note][:credit_note_id]} " \
                        "for #{state[:create_credit_note][:amount]}"
        logger.debug "Using receivables account: #{@export.receivables_account}"

        payment = @api.put('Payments', {
          'CreditNote' => { 'CreditNoteID' => state[:create_credit_note][:credit_note_id] },
          'Account' => { 'Code' => @export.receivables_account },
          'Date' => @export.date.strftime('%Y-%m-%d'),
          'Amount' => state[:create_credit_note][:amount],
          'Reference' => @export.reference
        })['Payments'].first
        current_state[:payment_id] = payment['PaymentID']
        current_state[:amount] = payment['Amount']
      end
    end

    private

    # Transfer an amount of money from one bank account to another
    #
    # @param from [String]
    # @param to [String]
    # @param amount [Float]
    # @return [void]
    def add_bank_transfer(from, to, amount)
      amount = amount.round(2)
      logger.debug "Transferring #{amount} from #{from} to #{to}"
      @api.put('BankTransfers', {
        'FromBankAccount' => { 'Code' => from },
        'ToBankAccount' => { 'Code' => to },
        'Amount' => amount,
        'Date' => @export.date.strftime('%Y-%m-%d')
      })['BankTransfers'].first
    end

    # Create an array of line item hashes which can be submitted to the Xero
    # API for the given array of lines
    #
    # @param lines [Hash]
    # @return [Array<Hash>]
    def create_xero_line_items(lines)
      lines.map do |(account, country, tax_rate), amounts|
        xero_tax_rate = find_or_create_tax_rate(country, tax_rate)

        if xero_tax_rate.nil?
          raise Error, "Could not determine tax rate for #{country} (#{tax_rate})"
        end

        {
          'Description' => @proposal.invoice_line_description(account, country, tax_rate),
          'Quantity' => 1,
          'AccountCode' => account,
          'TaxAmount' => amounts[:tax],
          'LineAmount' => amounts[:amount],
          'TaxType' => xero_tax_rate
        }
      end
    end

    # Add a fee transaction for a given amount to a given bank account
    #
    # @param bank_account [String]
    # @param amount [Float]
    # @return [void]
    def add_fee_transaction(bank_account, amount)
      return if amount.zero?

      @api.post('BankTransactions', {
        'Type' => amount.negative? ? 'RECEIVE' : 'SPEND',
        'Contact' => {
          'ContactID' => find_or_create_xero_contact(@export.payment_providers[bank_account] ||
                                                          'Generic Payment Processor')
        },
        'Date' => @export.date.strftime('%Y-%m-%d'),
        'BankAccount' => { 'Code' => bank_account },
        'Reference' => @export.reference,
        'LineItems' => [
          {
            'Description' => 'Fees',
            'UnitAmount' => amount.abs,
            'AccountCode' => @export.fee_accounts[bank_account] || '404'
          }
        ]
      })['BankTransactions'].first
    end

    # Find or create a contact with a given name and return the ID of that
    # contact
    #
    # @param name [String]
    # @return [String]
    def find_or_create_xero_contact(name)
      existing = @api.get('Contacts', where: "Name=\"#{name}\"")['Contacts']&.first
      if existing
        logger.debug "Found existing contact with name: #{name}"
        logger.debug "ID: #{existing['ContactID']}"
        return existing['ContactID']
      end

      logger.debug "Creating new contact with name: #{name}"
      response = @api.post('Contacts', 'Name' => name)
      id = response['Contacts'].first['ContactID']
      logger.debug "Contact created with ID: #{id}"
      id
    end

    # Find or create a tax rate for the given country and tax rate.
    #
    # @param country [XeroExporter::Country]
    # @param tax_rate [XeroExporter::TaxRate]
    # @return [String]
    def find_or_create_tax_rate(country, tax_rate)
      @tax_rate_cache ||= {}
      if cached_rate = @tax_rate_cache[[country, tax_rate]]
        return cached_rate
      end

      existing = tax_rates.find do |rate|
        rate['Status'] == 'ACTIVE' &&
          rate['ReportTaxType'] == tax_rate.xero_report_type &&
          rate['EffectiveRate'].to_d == tax_rate.rate.to_d &&
          rate['Name'].include?(country.code)
      end

      if existing
        @tax_rate_cache[[country, tax_rate]] = existing['TaxType']
        return existing['TaxType']
      end

      rates = @api.post('TaxRates', {
        'Name' => tax_rate.xero_name(country),
        'ReportTaxType' => tax_rate.xero_report_type,
        'TaxComponents' => [
          {
            'Name' => 'Tax',
            'Rate' => tax_rate.rate
          }
        ]
      })

      type = rates['TaxRates'].first['TaxType']
      @tax_rate_cache[[country, tax_rate]] = type
      type
    end

    # Return a full list of all tax rates currently stored within the API
    #
    # @return [Array<Hash>]
    def tax_rates
      @tax_rates ||= @api.get('TaxRates')['TaxRates'] || []
    end

    # Return the logger instance
    #
    # @return [Logger]
    def logger
      @logger || XeroExporter.logger
    end

    # Executes a named task if it is suitable to be executed
    #
    # @return [void]
    def run_task(name)
      if @state.nil?
        @state = load_state
      end

      if @state[name.to_sym] && @state[name.to_sym][:state] == 'complete'
        logger.debug "Not executing #{name} because it has already been run"
        return
      end

      logger.debug "Running #{name} task"

      @current_state = @state[name.to_sym] ||= {}
      @current_state[:state] = 'running'
      @current_state.delete(:error)
      yield if block_given?
    rescue StandardError => e
      if @current_state
        @current_state[:state] = 'error'
        @current_state[:error] = { class: e.class.name, message: e.message }
      end
      raise
    ensure
      if @current_state && @current_state[:state] == 'running'
        @current_state[:state] = 'complete'
      end

      @current_state = nil
      save_state
    end

    # Loads state as apprppriate
    #
    # @return [Hash]
    def load_state
      return {} unless @state_reader

      @state_reader.call
    end

    # Saves the current state as appropriate
    #
    # @return [void]
    def save_state
      return unless @state_writer

      @state_writer.call(@state)
    end

    attr_reader :state
    attr_reader :current_state

  end
end

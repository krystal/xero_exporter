# frozen_string_literal: true

require 'xero_exporter/proposal'

module XeroExporter
  class Executor

    def initialize(export, api)
      @export = export
      @api = api
      @proposal = Proposal.new(export)
    end

    # Execute all actions required to perform this export
    #
    # @return [void]
    def execute
      create_invoice
      create_credit_note
      add_payments
      add_refunds
      true
    end

    private

    # Create an invoice for all invoice lines in the export
    #
    # @return [void]
    def create_invoice
      line_items = create_xero_line_items(@proposal.invoice_lines)
      return false if line_items.empty?

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
      create_invoice_payment(invoice)
    end

    # Create a credit note for all credit note lines in the export
    #
    # @return [void]
    def create_credit_note
      line_items = create_xero_line_items(@proposal.credit_note_lines)
      return false if line_items.empty?

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
      create_credit_note_payment(credit_note)
    end

    # Create payments for all payments in the export
    #
    # @return [void]
    def add_payments
      @proposal.payments.each do |bank_account, amounts|
        add_bank_transfer(@export.receivables_account, bank_account, amounts[:amount])
        add_fee_transaction(bank_account, amounts[:fees])
      end
    end

    # Create refunds for all payments in the export
    #
    # @return [void]
    def add_refunds
      @proposal.refunds.each do |bank_account, amounts|
        add_bank_transfer(bank_account, @export.receivables_account, amounts[:amount])
        add_fee_transaction(bank_account, amounts[:fees])
      end
    end

    # Create a new payment that fully pays the given invoice
    #
    # @param invoice [Hash]
    # @return [void]
    def create_invoice_payment(invoice)
      return unless invoice['AmountDue'].positive?

      @api.put('Payments', {
        'Invoice' => { 'InvoiceID' => invoice['InvoiceID'] },
        'Account' => { 'Code' => @export.receivables_account },
        'Date' => @export.date.strftime('%Y-%m-%d'),
        'Amount' => invoice['AmountDue'],
        'Reference' => @export.reference
      })
    end

    # Create a new payment that fully pays a given credit note
    #
    # @param credit_note [Hash]
    # @return [void]
    def create_credit_note_payment(credit_note)
      reeturn unless credit_note['Total'].positive?

      @api.put('Payments', {
        'CreditNote' => { 'CreditNoteID' => credit_note['CreditNoteID'] },
        'Account' => { 'Code' => @export.receivables_account },
        'Date' => @export.date.strftime('%Y-%m-%d'),
        'Amount' => credit_note['Total'],
        'Reference' => @export.reference
      })
    end

    # Transfer an amount of money from one bank account to another
    #
    # @param from [String]
    # @param to [String]
    # @param amount [Float]
    # @return [void]
    def add_bank_transfer(from, to, amount)
      @api.put('BankTransfers', {
        'FromBankAccount' => { 'Code' => from },
        'ToBankAccount' => { 'Code' => to },
        'Amount' => amount,
        'Date' => @export.date.strftime('%Y-%m-%d')
      })
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
          'Description' => "Sales (#{country.code}, #{tax_rate.rate}%)",
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
        'Contact' => { 'ContactID' => find_or_create_xero_contact(@export.payment_providers[bank_account] || 'Generic Payment Processor') },
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
      })
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
          rate['EffectiveRate'].to_f == tax_rate.rate &&
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
      XeroExporter.logger
    end

  end
end

# frozen_string_literal: true

require 'xero_exporter/invoice'
require 'xero_exporter/payment'
require 'xero_exporter/refund'
require 'xero_exporter/executor'

module XeroExporter
  class Export

    attr_accessor :id
    attr_accessor :date
    attr_accessor :currency
    attr_accessor :invoice_contact_name

    attr_accessor :receivables_account
    attr_accessor :fee_accounts

    attr_reader :invoices
    attr_reader :payments
    attr_reader :refunds

    attr_reader :payment_providers

    def initialize
      @date = Date.today
      @currency = 'GBP'
      @invoice_contact_name = 'Generic Customer'
      @invoices = []
      @payments = []
      @refunds = []
      @payment_providers = {}
      @fee_accounts = {}
    end

    def reference
      "#{@date&.strftime('%Y%m%d')}-#{@currency&.upcase}-#{@id}"
    end

    def add_invoice
      invoice = Invoice.new
      yield invoice if block_given?
      @invoices << invoice
      invoice
    end

    def add_credit_note
      invoice = Invoice.new
      invoice.type = :credit_note
      yield invoice if block_given?
      @invoices << invoice
      invoice
    end

    def add_payment
      payment = Payment.new
      yield payment if block_given?
      @payments << payment
      payment
    end

    def add_refund
      refund = Refund.new
      yield refund if block_given?
      @refunds << refund
      refund
    end

    def execute(api)
      executor = Executor.new(self, api)
      executor.execute
    end

    private

    def logger
      XeroExporter.logger
    end

  end
end

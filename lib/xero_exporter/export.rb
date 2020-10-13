# frozen_string_literal: true

require 'xero_exporter/invoice'
require 'xero_exporter/payment'
require 'xero_exporter/refund'

module XeroExporter
  class Export

    attr_accessor :date
    attr_accessor :currency

    attr_reader :invoices
    attr_reader :payments
    attr_reader :refunds

    def initialize
      @invoices = []
      @payments = []
      @refunds = []
    end

    def add_invoice
      invoice = Invoice.new
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

  end
end

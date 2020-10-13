# frozen_string_literal: true

require 'xero_exporter/invoice_line'

module XeroExporter
  class Invoice

    attr_accessor :id
    attr_accessor :number
    attr_accessor :country
    attr_accessor :tax_rate
    attr_accessor :tax_type

    attr_reader :lines

    def initialize
      @lines = []
    end

    def add_line(account_code:, amount:, tax: 0.0)
      line = InvoiceLine.new
      line.account_code = account_code
      line.amount = amount
      line.tax = tax
      @lines << line
      line
    end

  end
end

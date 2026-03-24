# frozen_string_literal: true

require 'xero_exporter/invoice_line'
require 'xero_exporter/tax_rate'
require 'xero_exporter/country'

module XeroExporter
  class Invoice

    attr_accessor :id
    attr_accessor :number
    attr_accessor :type
    attr_writer :country
    attr_writer :tax_rate
    attr_writer :tax_type
    attr_writer :tax_rate_name

    attr_reader :lines

    def initialize
      @type = :invoice
      @lines = []
      @tax_type = :normal
    end

    def tax_rate
      if @tax_rate_name && @country
        raise Error, 'tax_rate_name and country cannot both be set'
      end

      TaxRate.new(@tax_rate, @tax_type, @tax_rate_name)
    end

    def country
      Country.new(@country)
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

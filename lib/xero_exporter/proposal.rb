# frozen_string_literal: true

module XeroExporter
  class Proposal

    def initialize(export)
      @export = export
    end

    # Returns an array of lines which need to be included on the invoice that will
    # be generated in Xero.
    #
    # @return [Hash]
    def invoice_lines
      export_lines = Hash.new { |h, k| h[k] = { amount: 0.0, tax: 0.0 } }
      @export.invoices.each do |invoice|
        invoice.lines.each do |line|
          key = [line.account_code, invoice.country, invoice.tax_rate]
          export_lines[key][:amount] += line.amount
          export_lines[key][:tax] += line.tax
        end
      end
      export_lines
    end

  end
end

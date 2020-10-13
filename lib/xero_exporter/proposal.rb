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
          export_lines[key][:amount] += line.amount || 0.0
          export_lines[key][:tax] += line.tax || 0.0
        end
      end
      export_lines
    end

    # Return the total number of payments per bank account which
    #
    # @return [Hash]
    def payments
      export_payments = Hash.new { |h, k| h[k] = { amount: 0.0, fees: 0.0 } }
      @export.payments.each do |payment|
        key = payment.bank_account
        export_payments[key][:amount] += payment.amount || 0.0
        export_payments[key][:fees] += payment.fees || 0.0
      end
      export_payments
    end

    # Return the total number of refund per bank account which
    #
    # @return [Hash]
    def refunds
      export_refunds = Hash.new { |h, k| h[k] = { amount: 0.0, fees: 0.0 } }
      @export.refunds.each do |refund|
        key = refund.bank_account
        export_refunds[key][:amount] += refund.amount || 0.0
        export_refunds[key][:fees] += refund.fees || 0.0
      end
      export_refunds
    end

  end
end

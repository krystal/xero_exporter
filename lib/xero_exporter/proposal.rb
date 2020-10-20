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
      get_invoice_lines_from_invoices(@export.invoices.select { |i| i.type == :invoice })
    end

    # Returns an array of lines which need to be included on the credit note that will
    # be generated in Xero.
    #
    # @return [Hash]
    def credit_note_lines
      get_invoice_lines_from_invoices(@export.invoices.select { |i| i.type == :credit_note })
    end

    # Return the total number of payments per bank account which
    #
    # @return [Hash]
    def payments
      export_payments = Hash.new(0.0)
      @export.payments.each do |payment|
        key = payment.bank_account
        export_payments[key] += payment.amount || 0.0
      end
      export_payments
    end

    # Return the total number of refund per bank account which
    #
    # @return [Hash]
    def refunds
      export_refunds = Hash.new(0.0)
      @export.refunds.each do |refund|
        key = refund.bank_account
        export_refunds[key] += refund.amount || 0.0
      end
      export_refunds
    end

    # Return the fees grouped by bank account & category
    #
    # @return [Hash]
    def fees
      initial_hash = Hash.new { |h, k| h[k] = Hash.new(0.0) }
      @export.fees.each_with_object(initial_hash) do |fee, hash|
        hash[fee.bank_account][fee.category] += fee.amount || 0.0
      end
    end

    # Return the text to go with an invoice line
    #
    # @return [String]
    def invoice_line_description(account, country, tax_rate)
      name = @export.account_names[account.to_s] || "#{account} Sales"
      "#{name} (#{country.code}, #{tax_rate.rate}%)"
    end

    private

    def get_invoice_lines_from_invoices(invoices)
      export_lines = Hash.new { |h, k| h[k] = { amount: 0.0, tax: 0.0 } }
      invoices.each do |invoice|
        invoice.lines.each do |line|
          key = [line.account_code, invoice.country, invoice.tax_rate]
          export_lines[key][:amount] += line.amount || 0.0
          export_lines[key][:tax] += line.tax || 0.0
        end
      end
      export_lines
    end

  end
end

# Xero Exporter

This library assists with exporting financial data into Xero. This assumes that your billing platform is handling all invoicing and payments and that you need to export that data into your Xero account on a daily basis.

The basic premise is that you'll present the required data to this library and it will handle sorting it and uploading it into Xero for you. The presentation should look like this...

```ruby
# Create an export instance with the date that you wish to export
# data from.
export = XeroExporter::Export.new

# Specify the date that you're exporting transactions for
export.date = Date.today

# Specify the currency that you're exporting transactions for
export.currency = 'GBP'

# Specify the ID for this export (for use in references)
export.id = '12345'

# Specify the name of the contact that should be used on any
# invoices that are generated. A contact will be found or created
# as appropriate.
export.invoice_contact_name = 'Generic Customer'

# You can then add all the invoices that you raised on this day to
# the export. It's important to ensure that you categorise the tax
# element on this as that forms a key part of the export.
export.add_invoice do |invoice|
  # For logging & reporting purposes, you can add the invoice
  # ID and/or number here. This won't actually be exported to Xero but
  # may be useful later for debugging purposes.
  invoice.id = 'inv_abcdef12345'
  invoice.number = 'INV-2020'

  # Specify the country code for this invoice
  invoice.country = 'GB'

  # Specify the tax rate that was charged for this invoice
  invoice.tax_rate = 20.0

  # Specify the type of tax that you're charging
  invoice.tax_type = :normal
  invoice.tax_type = :reverse_charge
  invoice.tax_type = :moss

  # Add the individual invoice lines that you wish to export
  # for this invoice by specifying the account code, the amount
  # and the amount of tax you calculated for that line.
  invoice.add_line account_code: '200', amount: 100.0, tax: 20.0
  invoice.add_line account_code: '205', amount: 100.0, tax: 20.0
end

# Additionally, you can also add credit notes in exactly the same
# way as an invoice. Just specify `invoice.type = :credit_note`
# above. All values should be positive when adding a credit note.

# Next, add all the payments that have been received on this day
# to the export.
export.add_payment do |payment|
  # As with invoices, this isn't exported but useful for logging
  # and debugging.
  payment.id = 'pay_abcdef12345'

  # Specify the amount of money that was received on this day
  payment.amount = 240.0

  # Specify the bank account code that the money was deposited into
  payment.bank_account = '010'

  # Specify the amount of fees that have been deducted for this payment.
  # If fees are deducted by a separate invoice by your payment provider
  # you should not specify these here.
  payment.fees = 2.30
end

# Next, do exactly the same as above with refunds really.
export.add_refund do |refund|
  # The refund identifier for logging/debugging
  refund.id = 'ref_abcde12345'

  # Specify the amount of the refund
  refund.amount = 10.0

  # Specify the bank account that the refund was taken from
  refund.bank_account = '010'

  # If any fees were charged or refunded to you for this refund, you
  # can specify them here. Refunded fees should be entered negatively.
  refund.fees = -0.50
end

# When you've added all your data to this export, you can go ahead and
# submit the export to Xero. The exporter will try and keep track of what's
# happening in a log file so you can see exactly what's going to be exported.

# Create a new API instance which can be used to authenticate to the API.
# You'll need to register appropriately with Xero to obtain client id/secret
# and then use OAuth to generate an access token.
api = XeroExporter::API.new(client_id, client_secret, access_token)

# Once you have your API instance, go ahead and initiate the export by providing
# your export instance and the ID of the organization that you wish to execute
# it against. You can also provider a logger which will receive useful text
# throughout the process outlining the current state of things.
api.export(tenant_id, export, logger: Logger.new(STDOUT))
```

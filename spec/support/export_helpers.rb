# frozen_string_literal: true

module ExportHelpers

  def create_export(yield_args: [])
    export = XeroExporter::Export.new
    export.id = '1234'
    export.invoice_contact_name = 'Example Customer'
    export.receivables_account = '020'
    export.fee_accounts['010'] = '010.404'
    export.payment_providers['010'] = 'Stripe'

    export.date = Date.new(2020, 10, 2)
    yield(export, *yield_args) if block_given?
    export
  end

  def create_executor(initial_state: {}, &block)
    api = XeroExporter::API.new('example', 'example')
    export = create_export(yield_args: [api], &block)
    state = initial_state.dup
    executor = XeroExporter::Executor.new(export, api)
    executor.state_writer = proc { |s| state = s }
    executor.state_reader = proc { state }
    [executor, state]
  end

end

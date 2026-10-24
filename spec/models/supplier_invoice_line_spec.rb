# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierInvoiceLine do
  let(:invoice) { SupplierInvoice.new(status: 'draft') }

  it 'accepts draft invoice lines for editing' do
    line = described_class.new(supplier_invoice: invoice, description: 'Service',
                               quantity: 1, unit_price: 100, amount: 100)

    expect(line).to be_valid
  end

  it 'refuses changes to an already posted invoice' do
    invoice.status = 'posted'
    line = described_class.new(supplier_invoice: invoice, description: 'Service',
                               quantity: 1, unit_price: 100, amount: 100)

    expect(line).not_to be_valid
    expect(line.errors[:base]).to include('Invoice is not editable')
  end

  it 'requires an associated draft invoice' do
    line = described_class.new(description: 'Unlinked', quantity: 1,
                               unit_price: 50, amount: 50)

    expect(line).not_to be_valid
    expect(line.errors[:base]).to include('Invoice is not editable')
  end

  it 'allows draft deletion but aborts destruction after posting' do
    line = described_class.new(supplier_invoice: invoice)
    expect { line.send(:invoice_must_be_draft_for_destroy) }.not_to change { line.errors.count }

    invoice.status = 'posted'
    outcome = catch(:abort) do
      line.send(:invoice_must_be_draft_for_destroy)
      :continued
    end

    expect(outcome).not_to eq(:continued)
    expect(line.errors[:base]).to include('Invoice is not editable')
  end
end

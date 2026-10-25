# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierInvoiceReceipt do
  let(:invoice) { SupplierInvoice.new(status: 'draft', organization_id: 41, purchase_order_id: 52) }
  let(:receipt) { GoodsReceipt.new(organization_id: 41, purchase_order_id: 52) }

  it 'allows a receipt linked to the same organization and purchase order' do
    join = described_class.new(supplier_invoice: invoice, goods_receipt: receipt)
    join.send(:matching_purchase)

    expect(join.errors[:goods_receipt]).to be_empty
    expect(join.errors[:base]).to be_empty
  end

  it 'rejects a receipt belonging to a different organization' do
    receipt.organization_id = 99
    join = described_class.new(supplier_invoice: invoice, goods_receipt: receipt)
    join.send(:matching_purchase)

    expect(join.errors[:goods_receipt]).to be_present
  end

  it 'rejects a receipt for an unrelated purchase order' do
    receipt.purchase_order_id = 98
    join = described_class.new(supplier_invoice: invoice, goods_receipt: receipt)
    join.send(:matching_purchase)

    expect(join.errors[:goods_receipt]).to be_present
  end

  it 'does not raise when either side is omitted' do
    join = described_class.new
    expect { join.send(:matching_purchase) }.not_to raise_error
    expect(join.errors[:goods_receipt]).to be_empty
  end

  it 'blocks editing and deletion after posting while preserving draft operations' do
    join = described_class.new(supplier_invoice: invoice)
    join.send(:invoice_must_be_draft)
    expect(join.errors[:base]).to be_empty

    invoice.status = 'posted'
    join.send(:invoice_must_be_draft)
    expect(join.errors[:base]).to include('Invoice is not editable')
    result = catch(:abort) do
      join.send(:invoice_must_be_draft_for_destroy)
      :continued
    end
    expect(result).not_to eq(:continued)
  end

  it 'rejects edits and destroys when the invoice association is missing' do
    join = described_class.new
    join.send(:invoice_must_be_draft)
    expect(join.errors[:base]).to include('Invoice is not editable')

    result = catch(:abort) do
      join.send(:invoice_must_be_draft_for_destroy)
      :continued
    end
    expect(result).not_to eq(:continued)
  end

  it 'does not attempt purchase matching if only an invoice is associated' do
    join = described_class.new(supplier_invoice: invoice)
    expect { join.send(:matching_purchase) }.not_to raise_error
    expect(join.errors[:goods_receipt]).to be_empty
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountsPayable::MatchReceipts do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:user) { create(:user) }
  let(:purchase_order) do
    PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency,
      requested_by: user, status: :ordered
    )
  end
  let(:invoice) do
    SupplierInvoice.create!(
      organization:, supplier:, purchase_order:, currency: supplier.currency,
      created_by: user, issued_on: Date.current, received_on: Date.current,
      due_on: Date.current + 15.days, total: 120, subtotal: 120
    )
  end
  let(:receipt) do
    GoodsReceipt.create!(
      organization:, branch:, purchase_order:, received_by: user,
      idempotency_key: 'receipt-for-invoice', received_at: Time.current, status: :posted
    )
  end

  it 'matches purchase receipts to a draft invoice and audits the action' do
    record = receipt

    expect do
      described_class.call(invoice:, receipt_ids: [record.id], actor: user)
    end.to change(SupplierInvoiceReceipt, :count).by(1)

    expect(invoice.reload.goods_receipts).to contain_exactly(record)
    expect(FinancialAuditEvent.where(event: 'invoice.receipts_matched', organization:)).to exist
  end

  it 'allows matching an existing receipt again after an earlier match was replaced' do
    record = receipt
    described_class.call(invoice:, receipt_ids: [record.id], actor: user)
    described_class.call(invoice:, receipt_ids: [], actor: user)

    expect do
      described_class.call(invoice:, receipt_ids: [record.id], actor: user)
    end.to change(SupplierInvoiceReceipt, :count).by(1)

    expect(invoice.reload.goods_receipts).to contain_exactly(record)
  end

  it 'rejects receipts from another purchase order' do
    other_order = PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency,
      requested_by: user, status: :ordered
    )
    other_receipt = GoodsReceipt.create!(
      organization:, branch:, purchase_order: other_order, received_by: user,
      idempotency_key: 'wrong-order', received_at: Time.current, status: :posted
    )

    expect do
      described_class.call(invoice:, receipt_ids: [other_receipt.id], actor: user)
    end.to raise_error(ArgumentError, 'Receipts must belong to the same purchase order')

    expect(invoice.supplier_invoice_receipts).to be_empty
  end

  it 'does not allow changing receipts after posting' do
    AccountsPayable::PostInvoice.call(invoice:, actor: user)

    expect do
      described_class.call(invoice:, receipt_ids: [], actor: user)
    end.to raise_error(ArgumentError, 'Only draft invoices can change receipts')
  end
end

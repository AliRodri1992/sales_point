# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Receipt matching integrity' do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }
  let(:order) do
    PurchaseOrder.create!(organization:, branch:, supplier:, currency: supplier.currency,
                          requested_by: user, status: :ordered)
  end
  let(:receipt) do
    GoodsReceipt.create!(
      organization:, branch:, purchase_order: order, received_by: user,
      idempotency_key: SecureRandom.uuid, received_at: Time.current, status: :posted
    )
  end

  def invoice
    SupplierInvoice.create!(
      organization:, supplier:, currency: supplier.currency, purchase_order: order, created_by: user,
      issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow,
      subtotal: 100, total: 100
    )
  end

  it 'rejects a receipt linked to another draft invoice' do
    first = invoice
    second = invoice
    described_class = AccountsPayable::MatchReceipts

    described_class.call(invoice: first, receipt_ids: [receipt.id], actor: user)
    expect do
      described_class.call(invoice: second, receipt_ids: [receipt.id], actor: user)
    end.to raise_error(ArgumentError, /already linked/)
  end

  it 'rejects reversed goods receipts' do
    record = receipt
    record.update!(status: :reversed)

    expect do
      AccountsPayable::MatchReceipts.call(invoice:, receipt_ids: [record.id], actor: user)
    end.to raise_error(ArgumentError, /same purchase order/)
  end

  it 'allows a new matching after the previous invoice is cancelled' do
    first = invoice
    second = invoice
    AccountsPayable::MatchReceipts.call(invoice: first, receipt_ids: [receipt.id], actor: user)
    first.update!(status: :cancelled)

    expect do
      AccountsPayable::MatchReceipts.call(invoice: second, receipt_ids: [receipt.id], actor: user)
    end.to change(SupplierInvoiceReceipt, :count).by(1)
  end
end

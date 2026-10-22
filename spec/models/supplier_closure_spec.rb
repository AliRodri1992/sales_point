# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier closing rules' do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user) }

  def draft_invoice
    SupplierInvoice.create!(
      organization:, supplier:, currency: supplier.currency, created_by: actor,
      issued_on: Date.current, received_on: Date.current, due_on: Date.current + 7.days,
      subtotal: 100, discount: 0, tax_amount: 0, total: 100, status: :draft, source: :manual
    )
  end

  it 'rejects new purchase orders from inactive suppliers' do
    supplier.update!(status: :inactive)
    order = PurchaseOrder.new(organization:, supplier:)
    expect(order).not_to be_valid
    expect(order.errors[:supplier]).to be_present
  end

  it 'rejects new purchase orders for archived suppliers' do
    supplier.update!(deleted_at: Time.current, status: :inactive)
    order = PurchaseOrder.new(organization:, supplier:)
    expect(order).not_to be_valid
  end

  it 'prevents supplier closure while an actual draft invoice exists' do
    invoice = draft_invoice
    expect(invoice).to be_persisted
    expect(supplier.archivable?).to be(false)
    expect(supplier.errors[:base]).to be_present
  end

  it 'does not post a draft invoice once its supplier becomes inactive' do
    invoice = draft_invoice
    supplier.update!(status: :inactive)

    expect { AccountsPayable::PostInvoice.call(invoice:, actor:) }
      .to raise_error(ArgumentError, /unavailable/)
    expect(invoice.reload).to be_draft
    expect(AccountPayable.where(supplier_invoice_id: invoice.id)).to be_empty
  end

  it 'does not post a draft invoice once its supplier is archived' do
    invoice = draft_invoice
    supplier.update!(deleted_at: Time.current, status: :inactive)

    expect { AccountsPayable::PostInvoice.call(invoice:, actor:) }
      .to raise_error(ArgumentError, /unavailable/)
    expect(invoice.reload).to be_draft
  end
end

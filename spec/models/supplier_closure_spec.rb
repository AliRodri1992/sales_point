# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier closing rules' do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }

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

  it 'prevents supplier closure while draft invoices exist' do
    allow(supplier.supplier_invoices).to receive(:exists?).with(status: 'draft')
                                        .and_return(true)
    expect(supplier.archivable?).to be(false)
  end
end

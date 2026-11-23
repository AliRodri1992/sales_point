# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier and purchasing record integrity' do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }

  def new_order
    PurchaseOrder.new(organization:, branch:, supplier:, currency: supplier.currency, requested_by: user)
  end

  it 'rechecks the supplier status when a pending insert locks the supplier' do
    order = new_order
    # A separate writer changes availability after the form loaded its supplier.
    Supplier.find(supplier.id).update!(status: 'inactive')

    expect { order.save! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(order.errors.of_kind?(:supplier, :invalid)).to be(true)
    expect(organization.purchase_orders).to be_empty
  end

  it 'carries the approved request and its branch into an order built from its quotation' do
    request = PurchaseRequest.create!(organization:, branch:, requested_by: user, status: :approved)
    quotation = PurchaseQuotation.create!(organization:, supplier:, currency: supplier.currency,
                                          purchase_request: request, status: :accepted)

    order = Purchases::BuildOrderFromQuotation.call(quotation:, requested_by: user)

    expect(order).to have_attributes(branch:, purchase_request: request, purchase_quotation: quotation)
  end

  it 'hides existing orders from a member without purchasing access' do
    create(:organization_membership, organization:, user:)
    order = new_order
    order.save!

    expect(PurchaseOrderPolicy::Scope.new(user, PurchaseOrder.all).resolve).not_to include(order)
  end

  [SupplierSchedule, SupplierEvent, SupplierProduct, PurchaseOrder].each do |model|
    it "marks a missing supplier as invalid for a new #{model.model_name.human}" do
      record = model.new
      record.valid?

      expect(record.errors.of_kind?(:supplier, :invalid)).to be(true)
    end
  end

  it 'rejects a bank account on a payment with no settlement currency' do
    record = SupplierPayment.new(organization:, supplier:, supplier_bank_account_id: -1,
                                 paid_on: Date.current, amount: 12, created_by: user)
    record.valid?

    expect(record.errors.of_kind?(:supplier_bank_account, :invalid)).to be(true)
  end
end

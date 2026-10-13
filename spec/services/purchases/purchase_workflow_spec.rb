# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Purchases::Workflow do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:requester) { create(:user) }
  let(:approver) { create(:user) }
  let(:product) { create(:product, organization:) }
  let(:order) do
    PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency,
      requested_by: requester
    )
  end

  before do
    order.purchase_order_items.create!(
      product:, quantity: 10, units_per_package: 5, unit_price: 50
    )
  end

  it 'submits, approves and dispatches a purchase order' do
    described_class.call(order:, action: :submit, user: requester)
    expect(order.reload).to be_pending_approval

    described_class.call(order:, action: :approve, user: approver)
    expect(order.reload).to be_approved
    expect(order.approved_by).to eq(approver)
    expect(order.purchase_approvals.last).to have_attributes(decision: 'approved', decided_by: approver)

    described_class.call(order:, action: :dispatch, user: approver)
    expect(order.reload).to be_ordered
  end

  it 'prevents self approval' do
    described_class.call(order:, action: :submit, user: requester)

    expect do
      described_class.call(order:, action: :approve, user: requester)
    end.to raise_error(ArgumentError, /own order/)
    expect(order.reload).to be_pending_approval
  end

  it 'requires at least one line to submit' do
    empty = PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency, requested_by: requester
    )
    expect do
      described_class.call(order: empty, action: :submit, user: requester)
    end.to raise_error(ArgumentError, /needs items/)
  end

  it 'rejects unsupported transitions' do
    expect do
      described_class.call(order:, action: :dispatch, user: approver)
    end.to raise_error(ArgumentError, /Invalid order/)
  end

  it 'records an explicit rejection of a pending order' do
    described_class.call(order:, action: :submit, user: requester)
    described_class.call(order:, action: :reject, user: approver)

    expect(order.reload).to be_rejected
    expect(order.purchase_approvals.last).to have_attributes(decision: 'rejected')
  end

  it 'supports approval of a submitted purchase request' do
    request = PurchaseRequest.create!(organization:, branch:, requested_by: requester)
    request.purchase_request_items.create!(product:, quantity: 4)

    described_class.submit_request!(request)
    expect(request.reload).to be_submitted

    described_class.decide_request!(request, status: 'approved', user: approver)
    expect(request.reload).to be_approved
  end

  it 'prevents a requester from approving their own purchase request' do
    request = PurchaseRequest.create!(organization:, branch:, requested_by: requester)
    request.purchase_request_items.create!(product:, quantity: 2)
    described_class.submit_request!(request)

    expect do
      described_class.decide_request!(request, status: 'approved', user: requester)
    end.to raise_error(ArgumentError, /own request/)
    expect(request.reload).to be_submitted
  end

  it 'rejects approval of an unsubmitted purchase request' do
    request = PurchaseRequest.create!(organization:, branch:, requested_by: requester)

    expect do
      described_class.decide_request!(request, status: 'approved', user: approver)
    end.to raise_error(ArgumentError, /submitted/)
  end

  it 'does not allow cancellation of an order after its reception' do
    described_class.call(order:, action: :submit, user: requester)
    described_class.call(order:, action: :approve, user: approver)
    described_class.call(order:, action: :dispatch, user: approver)
    Purchases::Receive.call(
      order:, user: requester, idempotency_key: 'receive-1',
      entries: [{ purchase_order_item_id: order.purchase_order_items.first.id,
                  delivered_quantity: 3, accepted_quantity: 3, damaged_quantity: 0 }]
    )

    expect do
      described_class.call(order:, action: :cancel, user: approver)
    end.to raise_error(ArgumentError, /cannot be cancelled/)
  end
end

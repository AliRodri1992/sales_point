# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchasing controller workflows and validation', type: :request do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:actor) { create(:user, :english) }
  let(:other_user) { create(:user) }

  before do
    create(:organization_membership, organization:, user: actor)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in actor
  end

  def request_record(requester: actor, status: :draft)
    PurchaseRequest.create!(organization:, branch:, requested_by: requester, status:)
  end

  def quotation_record(status: :draft, valid_until: nil)
    PurchaseQuotation.create!(organization:, supplier:, currency: supplier.currency, status:, valid_until:)
  end

  def order_record(requester: actor, status: :draft)
    PurchaseOrder.create!(organization:, branch:, supplier:, currency: supplier.currency, requested_by: requester,
                          status:)
  end

  it 'renders new request forms' do
    get new_admin_purchase_request_path
    expect(response).to have_http_status(:ok)
  end

  it 'edits draft purchase requests' do
    get edit_admin_purchase_request_path(request_record)
    expect(response).to have_http_status(:ok)
  end

  it 'updates the notes on a draft request' do
    record = request_record
    patch admin_purchase_request_path(record), params: {
      purchase_request: { branch_id: branch.id, notes: 'Restock before Friday' }
    }
    expect(record.reload.notes).to eq('Restock before Friday')
    expect(response).to redirect_to(admin_purchase_request_path(record))
  end

  it 'reports invalid branch on request update' do
    record = request_record
    other_branch = create(:branch, organization: create(:organization))
    patch admin_purchase_request_path(record), params: {
      purchase_request: { branch_id: other_branch.id }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(record.reload.branch).to eq(branch)
  end

  it 'rejects submitting an empty purchase request' do
    record = request_record
    post submit_admin_purchase_request_path(record)
    expect(record.reload).to be_draft
    expect(response).to redirect_to(admin_purchase_request_path(record))
  end

  it 'submits and cancels a request in the proper states' do
    record = request_record
    record.purchase_request_items.create!(product:, quantity: 2)
    post submit_admin_purchase_request_path(record)
    expect(record.reload).to be_submitted
    post cancel_admin_purchase_request_path(record)
    expect(record.reload).to be_submitted
  end

  it 'cancels a draft request' do
    record = request_record
    post cancel_admin_purchase_request_path(record)
    expect(record.reload).to be_cancelled
  end

  it 'approves a submitted request only by another person' do
    record = request_record(requester: other_user, status: :submitted)
    post approve_admin_purchase_request_path(record)
    expect(record.reload).to be_approved
  end

  it 'blocks approving ones own request' do
    record = request_record(status: :submitted)
    post approve_admin_purchase_request_path(record)
    expect(record.reload).to be_submitted
  end

  it 'rejects a submitted request from another requester' do
    record = request_record(requester: other_user, status: :submitted)
    post reject_admin_purchase_request_path(record)
    expect(record.reload).to be_rejected
  end

  it 'renders a new quotation' do
    get new_admin_purchase_quotation_path
    expect(response).to have_http_status(:ok)
  end

  it 'edits a draft quotation' do
    get edit_admin_purchase_quotation_path(quotation_record)
    expect(response).to have_http_status(:ok)
  end

  it 'updates a draft quotation' do
    record = quotation_record
    patch admin_purchase_quotation_path(record), params: {
      purchase_quotation: { supplier_id: supplier.id, currency_id: supplier.currency.id, notes: 'Next week' }
    }
    expect(response).to redirect_to(admin_purchase_quotation_path(record))
    expect(record.reload.notes).to eq('Next week')
  end

  it 'rejects invalid organization supplier when updating a quotation' do
    record = quotation_record
    foreign_supplier = create(:supplier, organization: create(:organization))
    patch admin_purchase_quotation_path(record), params: {
      purchase_quotation: { supplier_id: foreign_supplier.id }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects editing a submitted quotation' do
    record = quotation_record(status: :submitted)
    get edit_admin_purchase_quotation_path(record)
    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects updating a submitted quotation' do
    record = quotation_record(status: :submitted)
    patch admin_purchase_quotation_path(record), params: { purchase_quotation: { notes: 'Changed' } }
    expect(response).to have_http_status(:forbidden)
  end

  it 'submits a draft quotation' do
    record = quotation_record
    post submit_admin_purchase_quotation_path(record)
    expect(record.reload).to be_submitted
  end

  it 'cannot submit an already submitted quotation' do
    record = quotation_record(status: :submitted)
    post submit_admin_purchase_quotation_path(record)
    expect(record.reload).to be_submitted
    expect(response).to have_http_status(:forbidden)
  end

  it 'accepts a submitted valid quotation' do
    record = quotation_record(status: :submitted, valid_until: Date.tomorrow)
    post accept_admin_purchase_quotation_path(record)
    expect(record.reload).to be_accepted
  end

  it 'rejects an expired quotation' do
    record = quotation_record(status: :submitted, valid_until: Date.yesterday)
    post accept_admin_purchase_quotation_path(record)
    expect(record.reload).to be_submitted
    expect(response).to redirect_to(admin_purchase_quotation_path(record))
  end

  it 'rejects a submitted quotation' do
    record = quotation_record(status: :submitted)
    post reject_admin_purchase_quotation_path(record)
    expect(record.reload).to be_rejected
  end

  it 'renders new order form' do
    get new_admin_purchase_order_path
    expect(response).to have_http_status(:ok)
  end

  it 'renders order edit form' do
    get edit_admin_purchase_order_path(order_record)
    expect(response).to have_http_status(:ok)
  end

  it 'updates a draft order' do
    record = order_record
    patch admin_purchase_order_path(record), params: {
      purchase_order: { notes: 'New note', branch_id: branch.id, supplier_id: supplier.id,
                        currency_id: supplier.currency.id }
    }
    expect(response).to redirect_to(admin_purchase_order_path(record))
    expect(record.reload.notes).to eq('New note')
  end

  it 'rejects an order whose branch is from another organization' do
    record = order_record
    other_branch = create(:branch, organization: create(:organization))
    patch admin_purchase_order_path(record), params: {
      purchase_order: { branch_id: other_branch.id }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'cannot submit an empty order' do
    record = order_record
    post submit_admin_purchase_order_path(record)
    expect(record.reload).to be_draft
  end

  it 'submits an order with line items' do
    record = order_record
    record.purchase_order_items.create!(product:, quantity: 2, units_per_package: 1, unit_price: 10)
    post submit_admin_purchase_order_path(record)
    expect(record.reload).to be_pending_approval
  end

  it 'prevents approval of a self-submitted order' do
    record = order_record(status: :pending_approval)
    post approve_admin_purchase_order_path(record)
    expect(record.reload).to be_pending_approval
  end

  it 'approves and dispatches a colleague purchase order' do
    record = order_record(requester: other_user, status: :pending_approval)
    post approve_admin_purchase_order_path(record)
    expect(record.reload).to be_approved
    post send_order_admin_purchase_order_path(record)
    expect(record.reload).to be_ordered
  end

  it 'rejects a colleague purchase order with an audit decision' do
    record = order_record(requester: other_user, status: :pending_approval)
    post reject_admin_purchase_order_path(record)
    expect(record.reload).to be_rejected
    expect(record.purchase_approvals.count).to eq(1)
  end

  it 'cannot close an unreceived order' do
    record = order_record(status: :ordered)
    post close_admin_purchase_order_path(record)
    expect(record.reload).to be_ordered
  end

  it 'cancels a draft purchase order' do
    record = order_record
    post cancel_admin_purchase_order_path(record)
    expect(record.reload).to be_cancelled
  end
end

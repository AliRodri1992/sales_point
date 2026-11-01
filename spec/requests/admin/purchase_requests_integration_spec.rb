# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchasing access by organization', type: :request do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:product) { create(:product, organization:) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  it 'lists purchase requests for an authorized user' do
    get admin_purchase_requests_path

    expect(response).to have_http_status(:ok)
  end

  it 'creates a request with its line items and correct organization' do
    post admin_purchase_requests_path, params: {
      purchase_request: {
        branch_id: branch.id, notes: 'Restock products',
        purchase_request_items_attributes: {
          '0' => { product_id: product.id, quantity: 3 }
        }
      }
    }

    request_record = organization.purchase_requests.order(:id).last
    expect(response).to redirect_to(admin_purchase_request_path(request_record))
    expect(request_record.purchase_request_items.first).to have_attributes(product_id: product.id, quantity: 3)
    expect(request_record.requested_by).to eq(user)
  end

  it 'does not expose a request of another organization' do
    other_org = create(:organization)
    foreign_branch = create(:branch, organization: other_org)
    foreign = PurchaseRequest.create!(organization: other_org, branch: foreign_branch, requested_by: user)

    get admin_purchase_request_path(foreign)

    expect(response).to have_http_status(:not_found)
  end

  it 'does not permit creating a request against a foreign branch' do
    foreign_branch = create(:branch, organization: create(:organization))
    post admin_purchase_requests_path, params: {
      purchase_request: { branch_id: foreign_branch.id, notes: 'Invalid cross-tenant request' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(organization.purchase_requests.count).to eq(0)
  end
end

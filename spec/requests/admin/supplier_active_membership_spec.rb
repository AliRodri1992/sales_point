# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier access after membership deactivation', type: :request do
  let(:user) { create(:user, :english) }
  let(:archived_membership_organization) { create(:organization) }
  let(:active_organization) { create(:organization) }

  before do
    create(:organization_membership, user:, organization: archived_membership_organization, status: :inactive)
    create(:organization_membership, user:, organization: active_organization, status: :active)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  it 'does not list suppliers from a deactivated membership' do
    former = create(:supplier, organization: archived_membership_organization, name: 'Former membership supplier')
    current = create(:supplier, organization: active_organization, name: 'Accessible supplier')

    get admin_suppliers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(current.name)
    expect(response.body).not_to include(former.name)
  end

  it 'creates suppliers only in the organization with an active membership' do
    currency = create(:currency)
    attributes = attributes_for(:supplier).merge(currency_id: currency.id)

    post admin_suppliers_path, params: { supplier: attributes }

    expect(response).to redirect_to(admin_suppliers_path)
    expect(Supplier.order(:id).last.organization).to eq(active_organization)
  end

  it 'does not allow accessing a supplier of a deactivated organization' do
    former = create(:supplier, organization: archived_membership_organization)

    get admin_supplier_path(former)

    expect(response).to have_http_status(:not_found)
  end
end

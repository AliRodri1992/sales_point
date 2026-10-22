# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier dossier granular access', type: :request do
  let(:organization) { create(:organization) }
  let!(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    role = create(:system_role, role_type: :system, status: :active)
    role.permissions << Permission.create!(
      code: 'suppliers.contacts.manage', name: 'Manage supplier contacts',
      module_name: 'Proveedores', status: :active
    )
    create(:user_role, user:, system_role: role)
    sign_in user
  end

  it 'lists suppliers while masking fiscal data and hides unrelated sections' do
    get admin_suppliers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(supplier.name)
    expect(response.body).not_to include(supplier.rfc, supplier.email)

    get admin_supplier_path(supplier, tab: 'contacts')
    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('[data-section="contacts"]')).to be_present
    expect(page.at_css('[data-section="fiscal"]')).to be_nil
    expect(page.at_css('[data-section="documents"]')).to be_nil
  end

  it 'allows contact management but denies address management independently' do
    get admin_supplier_contacts_path(supplier)
    expect(response).to have_http_status(:ok)

    get admin_supplier_addresses_path(supplier)
    expect(response).to have_http_status(:forbidden)
  end
end

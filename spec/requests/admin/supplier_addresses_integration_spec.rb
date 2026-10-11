# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier address integration', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  def address_attributes(overrides = {})
    { street: 'Main Street', exterior_number: '12', neighborhood: 'Centro',
      city: 'Mexico City', state: 'CDMX', country: 'Mexico', postal_code: '06000',
      purpose: 'fiscal', primary: true }.merge(overrides)
  end

  it 'creates and displays a primary fiscal address' do
    post admin_supplier_addresses_path(supplier), params: { address: address_attributes }

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    address = supplier.addresses.last
    expect(address).to have_attributes(purpose: 'fiscal', primary: true)

    get admin_supplier_path(supplier, tab: 'addresses')
    expect(response.body).to include('Main Street')
  end

  it 'retains invalid input and shows a field-specific postal code error' do
    post admin_supplier_addresses_path(supplier),
         params: { address: address_attributes(postal_code: 'ABC') }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('ABC', 'data-server-field-error')
  end
end

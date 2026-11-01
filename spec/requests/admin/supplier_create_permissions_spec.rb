# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier registration section permissions', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }
  let(:role) { create(:system_role, role_type: :system, status: :active) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: role)
    grant('suppliers.create')
    sign_in user
  end

  def grant(code)
    role.permissions << Permission.find_or_create_by!(code:) do |permission|
      permission.name = code
      permission.module_name = 'Proveedores'
      permission.status = :active
    end
  end

  def create_supplier(attributes)
    post admin_suppliers_path, params: { supplier: { name: 'Restricted supplier', **attributes } }
  end

  it 'does not allow a create-only user to inject fiscal attributes' do
    expect do
      create_supplier(person_type: 'moral', rfc: 'XAXX010101000')
    end.not_to change(Supplier, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it 'does not allow a create-only user to inject commercial credit terms' do
    expect do
      create_supplier(credit_days: 60, credit_limit: 10_000)
    end.not_to change(Supplier, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it 'requires explicit contact permission for nested contacts during registration' do
    expect do
      create_supplier(contacts_attributes: { '0' => { name: 'Injected', primary: true } })
    end.not_to change(Supplier, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it 'requires explicit address permission for nested fiscal addresses during registration' do
    addresses = { '0' => { street: 'Hidden address', purpose: 'fiscal', primary: true } }
    expect do
      create_supplier(addresses_attributes: addresses)
    end.not_to change(Supplier, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it 'does not implicitly grant commercial edits when fiscal and contact permissions are present' do
    grant('suppliers.fiscal.manage')
    grant('suppliers.contacts.manage')
    create_supplier(person_type: 'moral', credit_days: 60)

    expect(response).to have_http_status(:forbidden)
    expect(organization.suppliers.count).to eq(0)
  end
end

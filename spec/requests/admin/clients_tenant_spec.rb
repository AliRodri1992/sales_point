# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin clients tenant isolation', type: :request do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  before do
    create(:organization_membership, user:, organization:)
    role = create(:system_role, :system)
    create(:user_role, user:, system_role: role)
    GranularPermissionCatalog.sync!
    permissions = Permission.where(
      code: GranularPermissionCatalog::ACTIONS.map { |action| "customers.#{action}" }
    )
    permissions.find_each { |permission| create(:system_role_permission, system_role: role, permission:) }
    sign_in user
  end

  it 'lists only clients owned by the selected organization' do
    create(:client, organization:, name: 'Owned Client')
    create(:client, organization: other_organization, name: 'Foreign Client')
    get admin_clients_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Owned Client')
    expect(response.body).not_to include('Foreign Client')
  end

  it 'rejects show, edit, update and deletion of a foreign client' do
    foreign = create(:client, organization: other_organization, name: 'Protected Client')

    get admin_client_path(foreign)
    expect(response).to have_http_status(:not_found)
    get edit_admin_client_path(foreign)
    expect(response).to have_http_status(:not_found)
    patch admin_client_path(foreign), params: { client: { name: 'Changed' } }
    expect(response).to have_http_status(:not_found)
    delete admin_client_path(foreign)
    expect(response).to have_http_status(:not_found)

    expect(foreign.reload.name).to eq('Protected Client')
    expect(foreign.deleted_at).to be_nil
  end

  it 'ignores a forged tenant when creating a client' do
    post admin_clients_path, params: {
      client: { code: 'SAFE-001', name: 'Owned New Client', organization_id: other_organization.id }
    }

    expect(response).to redirect_to(admin_clients_path)
    expect(Client.find_by!(code: 'SAFE-001').organization).to eq(organization)
  end

  it 'allows the same code and RFC in separate organizations' do
    create(:client, organization: other_organization, code: 'DUPLICATE',
                    rfc: 'XAXX010101987')
    post admin_clients_path, params: {
      client: { code: 'DUPLICATE', name: 'Independent Buyer', rfc: 'XAXX010101987' }
    }

    expect(response).to redirect_to(admin_clients_path)
    expect(Client.where(code: 'DUPLICATE').pluck(:organization_id)).to contain_exactly(
      other_organization.id, organization.id
    )
  end

  it 'keeps ambiguous historic clients inaccessible until ownership is reconciled' do
    legacy = create(:client, organization:, code: 'LEGACY-LOCKED', name: 'Unassigned Legacy')
    # Simulate an existing pre-tenant row without changing application validation rules.
    Client.connection.execute("UPDATE clients SET organization_id = NULL WHERE id = #{legacy.id}")

    get admin_clients_path
    expect(response.body).not_to include('Unassigned Legacy')

    legacy = Client.find_by!(code: 'LEGACY-LOCKED')
    get admin_client_path(legacy)
    expect(response).to have_http_status(:not_found)
  end

  it 'stores customer notes under the same organization' do
    post admin_clients_path, params: {
      client: { code: 'NOTE-ORG', name: 'Customer Note', notes: 'Internal note' }
    }
    expect(response).to redirect_to(admin_clients_path)

    client = Client.find_by!(code: 'NOTE-ORG')
    expect(client.note_entries.general.first.organization).to eq(organization)
  end

  it 'does not allow client phones to belong to a foreign organization' do
    client = create(:client, organization:)
    phone = client.phones.build(number: '5512345678', country_code: 'MX', kind: 'mobile',
                                primary: true, organization: other_organization)

    expect(phone).not_to be_valid
    expect(phone.errors[:organization]).to be_present
  end
end

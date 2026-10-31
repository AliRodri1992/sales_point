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

  it 'lists masked suppliers for access-only and delete-only users without opening dossiers' do
    role = user.user_roles.first.system_role
    role.permissions.clear
    permission = create(:permission, code: 'suppliers.access', module_name: 'Proveedores')
    role.permissions << permission

    get admin_suppliers_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(supplier.name)
    expect(response.body).not_to include(supplier.rfc, supplier.email)
    get admin_supplier_path(supplier)
    expect(response).to have_http_status(:forbidden)

    permission.update!(code: 'suppliers.destroy')
    get admin_suppliers_path
    expect(response).to have_http_status(:ok)
    expect(SupplierPolicy.new(user, supplier).destroy?).to be(true)
    expect(SupplierPolicy.new(user, supplier).show?).to be(false)
  end

  it 'allows contact management but denies address management independently' do
    get admin_supplier_contacts_path(supplier)
    expect(response).to have_http_status(:ok)

    get admin_supplier_addresses_path(supplier)
    expect(response).to have_http_status(:forbidden)
  end
  it 'permits contact creation without granting contact updates or deletion' do
    role = user.user_roles.first.system_role
    role.permissions.clear
    role.permissions << create(:permission, code: 'suppliers.contacts.create', module_name: 'Proveedores')
    contact = create(:contact, contactable: supplier)

    get new_admin_supplier_contact_path(supplier)
    expect(response).to have_http_status(:ok)

    get edit_admin_supplier_contact_path(supplier, contact)
    expect(response).to have_http_status(:forbidden)

    delete admin_supplier_contact_path(supplier, contact)
    expect(response).to have_http_status(:forbidden)
    expect(contact.reload.deleted_at).to be_nil

    get admin_supplier_contacts_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(contact.name)
    expect(response.body).not_to include(edit_admin_supplier_contact_path(supplier, contact))
  end

  it 'grants address updates without allowing a new address' do
    role = user.user_roles.first.system_role
    role.permissions.clear
    role.permissions << create(:permission, code: 'suppliers.addresses.update', module_name: 'Proveedores')
    address = create(:address, addressable: supplier)

    get edit_admin_supplier_address_path(supplier, address)
    expect(response).to have_http_status(:ok)

    get new_admin_supplier_address_path(supplier)
    expect(response).to have_http_status(:forbidden)
  end

  it 'permits new schedules without permitting existing schedule deletion' do
    role = user.user_roles.first.system_role
    role.permissions.clear
    role.permissions << create(:permission, code: 'suppliers.schedules.create', module_name: 'Proveedores')
    schedule = supplier.supplier_schedules.create!(
      branch: create(:branch, organization:), kind: 'visit', weekday: 2,
      starts_at: Time.zone.parse('09:00'), ends_at: Time.zone.parse('10:00')
    )

    get new_admin_supplier_schedule_path(supplier)
    expect(response).to have_http_status(:ok)

    delete admin_supplier_schedule_path(supplier, schedule)
    expect(response).to have_http_status(:forbidden)
    expect(schedule.reload.deleted_at).to be_nil
  end

end

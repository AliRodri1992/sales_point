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

  it 'does not reveal contact details through search to access-only users' do
    role = user.user_roles.first.system_role
    role.permissions.clear
    role.permissions << create(:permission, code: 'suppliers.access', module_name: 'Proveedores')
    create(:contact, contactable: supplier, primary: true, email: 'hidden@vendor.example')

    get admin_suppliers_path, params: { search: 'hidden@vendor.example' }

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(supplier.name)
  end

  it 'limits general-only contact search to the active primary contact' do
    role = user.user_roles.first.system_role
    role.permissions.clear
    role.permissions << create(:permission, code: 'suppliers.view', module_name: 'Proveedores')
    create(:contact, contactable: supplier, primary: true, email: 'main@vendor.example')
    create(:contact, contactable: supplier, primary: false, email: 'secondary@vendor.example')

    get admin_suppliers_path, params: { search: 'secondary@vendor.example' }
    expect(response.body).not_to include(supplier.name)

    get admin_suppliers_path, params: { search: 'main@vendor.example' }
    expect(response.body).to include(supplier.name)
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
    expect(response).to have_http_status(:forbidden)

    post admin_supplier_contacts_path(supplier), params: { contact: { name: 'Creation only contact' } }
    expect(response).to have_http_status(:redirect)
    expect(supplier.contacts.not_deleted.find_by(name: 'Creation only contact')).to be_present
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

  it 'allows document upload without granting document removal or metadata editing' do
    role = user.user_roles.first.system_role
    role.permissions.clear
    role.permissions << create(:permission, code: 'suppliers.documents.create', module_name: 'Proveedores')

    policy = SupplierPolicy.new(user, supplier)
    expect(policy.view_documents?).to be(false)
    expect(policy.read_documents?).to be(false)
    expect(policy.create_documents?).to be(true)
    expect(policy.update_documents?).to be(false)
    expect(policy.destroy_documents?).to be(false)
    expect(policy.restore_documents?).to be(false)

    get admin_supplier_path(supplier, tab: 'documents')
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('data-section="documents"')
  end

  it 'separates product offer creation from editing and preferred selection' do
    role = user.user_roles.first.system_role
    role.permissions.clear
    role.permissions << create(:permission, code: 'suppliers.products.create', module_name: 'Proveedores')

    policy = SupplierPolicy.new(user, supplier)
    expect(policy.view_products?).to be(false)
    expect(policy.create_products?).to be(true)
    expect(policy.update_products?).to be(false)
    expect(policy.destroy_products?).to be(false)
    expect(policy.restore_products?).to be(false)
    expect(policy.prefer_products?).to be(false)

    get admin_supplier_supplier_products_path(supplier)
    expect(response).to have_http_status(:forbidden)

    get new_admin_supplier_supplier_product_path(supplier)
    expect(response).to have_http_status(:ok)
  end

  it 'creates a product offer without exposing the restricted offer listing' do
    role = user.user_roles.first.system_role
    role.permissions.clear
    role.permissions << create(:permission, code: 'suppliers.products.create', module_name: 'Proveedores')
    item = create(:product, organization:)

    post admin_supplier_supplier_products_path(supplier), params: {
      supplier_product: {
        product_id: item.id, currency_id: supplier.currency.id, presentation_name: 'Box',
        units_per_package: 12, purchase_price: 120, minimum_quantity: 1,
        discount_percent: 0, freight_amount: 0, nonrecoverable_tax: 0, lead_time_days: 3
      }
    }

    expect(response).to redirect_to(admin_suppliers_path)
    expect(supplier.supplier_products.find_by(product: item)).to be_present
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier contacts, addresses and schedules full CRUD', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user, :english) }
  let(:branch) { create(:branch, organization:) }

  before do
    create(:organization_membership, user: actor, organization:)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in actor
  end

  def new_address
    supplier.addresses.create!(
      street: 'Main Street', exterior_number: '10', city: 'CDMX', state: 'CDMX',
      neighborhood: 'Centro', country: create(:country, iso_alpha2: 'MX'), postal_code: '06000',
      purpose: 'fiscal'
    )
  end

  def schedule
    supplier.supplier_schedules.create!(
      branch:, kind: 'visit', weekday: 1, starts_at: '09:00', ends_at: '11:00'
    )
  end

  it 'renders supplier contacts index' do
    get admin_supplier_contacts_path(supplier)
    expect(response).to have_http_status(:ok)
  end

  it 'renders existing contact edit form' do
    contact = create(:contact, contactable: supplier)
    get edit_admin_supplier_contact_path(supplier, contact)
    expect(response).to have_http_status(:ok)
  end

  it 'updates the supplier contact' do
    contact = create(:contact, contactable: supplier)
    patch admin_supplier_contact_path(supplier, contact), params: { contact: { name: 'Updated contact' } }
    expect(response).to redirect_to(admin_supplier_contacts_path(supplier))
    expect(contact.reload.name).to eq('Updated contact')
  end

  it 'preserves the original contact after invalid edits' do
    contact = create(:contact, contactable: supplier)
    patch admin_supplier_contact_path(supplier, contact), params: { contact: { name: '' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(contact.reload.name).to be_present
  end

  it 'archives and restores a supplier contact' do
    contact = create(:contact, contactable: supplier)
    delete admin_supplier_contact_path(supplier, contact)
    expect(contact.reload.deleted_at).to be_present
    patch restore_admin_supplier_contact_path(supplier, contact)
    expect(response).to redirect_to(admin_supplier_contacts_path(supplier))
    expect(contact.reload.deleted_at).to be_nil
  end

  it 'lists supplier addresses' do
    get admin_supplier_addresses_path(supplier)
    expect(response).to have_http_status(:ok)
  end

  it 'renders a new supplier address form' do
    get new_admin_supplier_address_path(supplier)
    expect(response).to have_http_status(:ok)
  end

  it 'renders the edit supplier address form' do
    address = new_address
    get edit_admin_supplier_address_path(supplier, address)
    expect(response).to have_http_status(:ok)
  end

  it 'updates valid address details' do
    address = new_address
    patch admin_supplier_address_path(supplier, address), params: {
      address: { street: 'Second Street' }
    }
    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(address.reload.street).to eq('Second Street')
  end

  it 'rejects invalid address updates' do
    address = new_address
    patch admin_supplier_address_path(supplier, address), params: {
      address: { postal_code: 'INVALID' }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'archives and restores supplier addresses' do
    address = new_address
    delete admin_supplier_address_path(supplier, address)
    expect(address.reload.deleted_at).to be_present
    patch restore_admin_supplier_address_path(supplier, address)
    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(address.reload.deleted_at).to be_nil
  end

  it 'renders supplier schedules index and new' do
    get admin_supplier_schedules_path(supplier)
    expect(response).to have_http_status(:ok)
    get new_admin_supplier_schedule_path(supplier)
    expect(response).to have_http_status(:ok)
  end

  it 'renders editing an existing supplier schedule' do
    record = schedule
    get edit_admin_supplier_schedule_path(supplier, record)
    expect(response).to have_http_status(:ok)
  end

  it 'rejects an invalid schedule update' do
    record = schedule
    patch admin_supplier_schedule_path(supplier, record), params: {
      supplier_schedule: { starts_at: '15:00', ends_at: '11:00' }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(record.reload.starts_at.strftime('%H:%M')).to eq('09:00')
  end

  it 'archives and restores supplier schedules' do
    record = schedule
    delete admin_supplier_schedule_path(supplier, record)
    expect(record.reload.deleted_at).to be_present
    patch restore_admin_supplier_schedule_path(supplier, record)
    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    expect(record.reload.deleted_at).to be_nil
  end
end

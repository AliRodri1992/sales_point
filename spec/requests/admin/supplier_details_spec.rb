# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier contacts and addresses', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: admin_role)
    sign_in user
  end

  it 'creates and soft deletes supplier contacts' do
    post admin_supplier_contacts_path(supplier), params: { contact: { name: 'Purchasing', email: 'buyer@example.com' } }
    expect(response).to have_http_status(:redirect)
    contact = supplier.contacts.last
    expect(contact.name).to eq('Purchasing')

    sign_in user
    delete admin_supplier_contact_path(supplier, contact)
    expect(contact.reload.deleted_at).to be_present
  end

  it 'rejects duplicate active primary contacts' do
    create(:contact, contactable: supplier, primary: true)
    post admin_supplier_contacts_path(supplier), params: { contact: { name: 'Second', primary: true } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(supplier.contacts.not_deleted.count).to eq(1)
  end

  it 'creates and soft deletes supplier addresses' do
    mexico = Country.find_by(iso_alpha2: 'MX') ||
             create(:country, iso_alpha2: 'MX', iso_alpha3: 'MEX', iso_numeric: '484')
    post admin_supplier_addresses_path(supplier), params: {
      address: attributes_for(:address).slice(
        :street, :exterior_number, :interior_number, :neighborhood, :city, :state, :postal_code
      ).merge(country_id: mexico.id)
    }
    expect(response).to have_http_status(:redirect)
    address = supplier.addresses.last
    expect(address).to be_present

    sign_in user
    delete admin_supplier_address_path(supplier, address)
    expect(address.reload.deleted_at).to be_present
  end

  it 'does not expose another organization contacts or addresses' do
    foreign_supplier = create(:supplier, organization: create(:organization))
    foreign_contact = create(:contact, contactable: foreign_supplier)
    foreign_address = create(:address, addressable: foreign_supplier)

    get admin_supplier_contacts_path(foreign_supplier)
    expect(response).to have_http_status(:not_found)

    sign_in user
    patch admin_supplier_contact_path(foreign_supplier, foreign_contact), params: { contact: { name: 'Changed' } }
    expect(response).to have_http_status(:not_found)
    expect(foreign_contact.reload.name).not_to eq('Changed')

    sign_in user
    delete admin_supplier_address_path(foreign_supplier, foreign_address)
    expect(response).to have_http_status(:not_found)
    expect(foreign_address.reload.deleted_at).to be_nil
  end
  it 'restores a deleted primary contact without losing its designation' do
    contact = create(:contact, contactable: supplier, primary: true)
    delete admin_supplier_contact_path(supplier, contact)
    expect(contact.reload).to be_primary
    expect(contact.deleted_at).to be_present

    sign_in user
    patch restore_admin_supplier_contact_path(supplier, contact)
    expect(response).to have_http_status(:redirect)
    expect(contact.reload.deleted_at).to be_nil
    expect(contact).to be_primary
  end

  it 'rejects restoring a primary address when another is already primary' do
    address = create(:address, addressable: supplier, primary: true)
    delete admin_supplier_address_path(supplier, address)
    create(:address, addressable: supplier, primary: true)

    sign_in user
    patch restore_admin_supplier_address_path(supplier, address)
    expect(response).to have_http_status(:redirect)
    expect(address.reload.deleted_at).to be_present
  end

  it 'does not restore a contact belonging to another organization' do
    foreign_supplier = create(:supplier, organization: create(:organization))
    contact = create(:contact, contactable: foreign_supplier, deleted_at: Time.current)
    patch restore_admin_supplier_contact_path(foreign_supplier, contact)
    expect(response).to have_http_status(:not_found)
    expect(contact.reload.deleted_at).to be_present
  end
end

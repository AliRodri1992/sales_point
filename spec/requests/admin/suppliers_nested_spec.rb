# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier nested dossier', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }
  let(:currency) { create(:currency) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: admin_role)
    sign_in user
  end

  def address_attributes
    { street: 'Main Street', exterior_number: '12', neighborhood: 'Centro',
      city: 'Mexico City', state: 'CDMX', country_id: create(:country, iso_alpha2: 'MX').id,
      postal_code: '06000', purpose: 'fiscal', primary: true }
  end

  it 'rejects multiple contacts in one creation request' do
    attributes = attributes_for(:supplier).merge(
      currency_id: currency.id,
      contacts_attributes: {
        '0' => { name: 'Primary', email: 'PRIMARY@EXAMPLE.COM', phone: '5512345678', primary: true },
        '1' => { name: 'Secondary', mobile_phone: '5512345679', primary: false }
      },
      addresses_attributes: { '0' => address_attributes }
    )

    before_count = Supplier.count
    post admin_suppliers_path, params: { supplier: attributes }

    errors = Nokogiri::HTML(response.body).css('[data-server-field-error]').map(&:text).join(' | ')
    expect(response).to have_http_status(:unprocessable_content)
    expect(Supplier.count).to eq(before_count), errors
  end

  it 'creates exactly one primary contact and fiscal address' do
    post admin_suppliers_path, params: { supplier: attributes_for(:supplier).merge(
      currency_id: currency.id,
      contacts_attributes: { '0' => { name: 'Primary', primary: true } },
      addresses_attributes: { '0' => address_attributes }
    ) }

    expect(response).to have_http_status(:redirect)
    saved = Supplier.order(:id).last
    expect(saved.contacts.first).to be_primary
    expect(saved.addresses.first).to have_attributes(primary: true, purpose: 'fiscal')
  end

  it 'enforces primary contact and fiscal address when flags are omitted' do
    post admin_suppliers_path, params: { supplier: attributes_for(:supplier).merge(
      currency_id: currency.id,
      contacts_attributes: { '0' => { name: 'Main contact' } },
      addresses_attributes: { '0' => address_attributes.except(:purpose, :primary) }
    ) }

    expect(response).to redirect_to(admin_suppliers_path)
    saved = Supplier.order(:id).last
    expect(saved.contacts.first).to be_primary
    expect(saved.addresses.first).to have_attributes(purpose: 'fiscal', primary: true)
  end

  it 'geocodes the newly registered supplier fiscal address using the complete address' do
    allow(GeocodeAddressJob).to receive(:perform_later)

    post admin_suppliers_path, params: { supplier: attributes_for(:supplier).merge(
      currency_id: currency.id, addresses_attributes: { '0' => address_attributes }
    ) }

    expect(response).to redirect_to(admin_suppliers_path)
    address = Supplier.order(:id).last.addresses.first
    expect(GeocodeAddressJob).to have_received(:perform_later).with(
      address.id, address.geocoding_fingerprint
    ).once
  end

  it 'geocodes a changed fiscal address when edited through the main supplier form' do
    supplier = create(:supplier, organization:)
    address = supplier.addresses.create!(address_attributes)
    allow(GeocodeAddressJob).to receive(:perform_later)

    patch admin_supplier_path(supplier), params: { supplier: {
      addresses_attributes: { '0' => { id: address.id, street: 'Changed street' } }
    } }

    expect(response).to redirect_to(admin_suppliers_path)
    expect(GeocodeAddressJob).to have_received(:perform_later).with(
      address.id, address.reload.geocoding_fingerprint
    ).once
  end

  it 'does not enqueue geocoding when an update has no address changes' do
    supplier = create(:supplier, organization:)
    supplier.addresses.create!(address_attributes)
    allow(GeocodeAddressJob).to receive(:perform_later)

    patch admin_supplier_path(supplier), params: { supplier: { name: 'Updated supplier name' } }

    expect(response).to redirect_to(admin_suppliers_path)
    expect(GeocodeAddressJob).not_to have_received(:perform_later)
  end

  it 'rejects an explicit nonfiscal address in the supplier registration payload' do
    post admin_suppliers_path, params: { supplier: attributes_for(:supplier).merge(
      currency_id: currency.id,
      addresses_attributes: { '0' => address_attributes.merge(purpose: 'delivery') }
    ) }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'retains invalid nested address and contact values in the response' do
    post admin_suppliers_path, params: {
      supplier: attributes_for(:supplier).merge(
        currency_id: currency.id,
        contacts_attributes: { '0' => { name: 'Invalid contact', email: 'not-an-email' } },
        addresses_attributes: { '0' => address_attributes.merge(postal_code: 'INVALID') }
      )
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('not-an-email', 'INVALID')
    expect(response.body).to include('data-server-field-error')
  end

  it 'updates existing nested records without replacing their identifiers' do
    supplier = create(:supplier, organization:)
    contact = supplier.contacts.create!(name: 'Original', primary: true)
    address = supplier.addresses.create!(address_attributes)

    patch admin_supplier_path(supplier), params: {
      supplier: {
        contacts_attributes: { '0' => { id: contact.id, name: 'Updated' } },
        addresses_attributes: { '0' => { id: address.id, street: 'Updated Street' } }
      }
    }

    expect(response).to redirect_to(admin_suppliers_path)
    expect(contact.reload.name).to eq('Updated')
    expect(address.reload.street).to eq('Updated Street')
  end
end

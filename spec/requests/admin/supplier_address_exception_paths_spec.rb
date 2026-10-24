# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier address exceptional lifecycle paths', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }
  let(:country) { Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX') }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def attributes(overrides = {})
    { country_id: country.id, street: 'Central Avenue', exterior_number: '42',
      city: 'Mexico City', state: 'CDMX', neighborhood: 'Centro', postal_code: '06000',
      purpose: 'fiscal', primary: true }.merge(overrides)
  end

  def address(overrides = {})
    create(:address, :fiscal, addressable: supplier, **attributes.except(:country_id), country:, **overrides)
  end

  it 'handles a concurrent unique-primary conflict when creating an address' do
    allow(Suppliers::SaveAddress).to receive(:new).and_raise(ActiveRecord::RecordNotUnique)
    post admin_supplier_addresses_path(supplier), params: { address: attributes }

    expect(response).to have_http_status(:unprocessable_content)
    expect(supplier.addresses.count).to be_zero
  end

  it 'handles a concurrent unique-primary conflict when editing an address' do
    record = address
    allow(Suppliers::SaveAddress).to receive(:new).and_raise(ActiveRecord::RecordNotUnique)
    patch admin_supplier_address_path(supplier, record),
          params: { address: attributes(street: 'Changed Avenue', primary: false) }

    expect(response).to have_http_status(:unprocessable_content)
    expect(record.reload.street).not_to eq('Changed Avenue')
  end

  it 'reports a failed primary switch without exposing a database exception' do
    record = address
    allow(Suppliers::SetPrimaryAddress).to receive(:new).and_raise(ActiveRecord::RecordNotUnique)
    patch set_primary_admin_supplier_address_path(supplier, record)

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(flash[:alert]).to be_present
  end

  it 'keeps an existing primary address when it is selected again' do
    record = address(primary: true)
    patch set_primary_admin_supplier_address_path(supplier, record)

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(record.reload).to be_primary
  end

  it 'rejects restoring an archived primary address over an active primary' do
    old = address(primary: true, deleted_at: Time.current)
    current = address(primary: true, street: 'Current fiscal')

    patch restore_admin_supplier_address_path(supplier, old)

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(flash[:alert]).to be_present
    expect(old.reload.deleted_at).to be_present
    expect(current.reload).to be_primary
  end

  it 'does not requeue geocoding unless the previous lookup failed' do
    record = address(geocoding_status: :pending)
    allow(GeocodeAddressJob).to receive(:perform_later)
    post retry_geocoding_admin_supplier_address_path(supplier, record)

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(GeocodeAddressJob).not_to have_received(:perform_later)
  end

  it 'requeues a failed address geocoding without changing the fiscal address' do
    record = address(geocoding_status: :failed)
    allow(GeocodeAddressJob).to receive(:perform_later)
    post retry_geocoding_admin_supplier_address_path(supplier, record)

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(record.reload.geocoding_status).to eq('pending')
    expect(GeocodeAddressJob).to have_received(:perform_later).with(
      record.id, record.geocoding_fingerprint
    ).once
  end
end

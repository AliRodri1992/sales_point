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
      city: 'Mexico City', state: 'CDMX', country_id: create(:country).id,
      postal_code: '06000', purpose: 'fiscal', primary: true }
  end

  it 'creates supplier with multiple contacts and a fiscal address' do
    attributes = attributes_for(:supplier).merge(currency_id: currency.id,
      contacts_attributes: {
        '0' => { name: 'Primary', email: 'PRIMARY@EXAMPLE.COM', phone: '5512345678', primary: true },
        '1' => { name: 'Secondary', mobile_phone: '5512345679', primary: false }
      },
      addresses_attributes: { '0' => address_attributes }
    )

    expect do
      post admin_suppliers_path, params: { supplier: attributes }
    end.to change(Supplier, :count).by(1)

    supplier = Supplier.order(:id).last
    expect(supplier.contacts.count).to eq(2)
    expect(supplier.addresses.count).to eq(1)
    expect(supplier.contacts.find_by!(name: 'Primary').email).to eq('primary@example.com')
    expect(supplier.contacts.find_by!(name: 'Primary').phone).to start_with('+52')
    expect(supplier.addresses.first.purpose).to eq('fiscal')
  end

  it 'retains invalid nested address and contact values in the response' do
    post admin_suppliers_path, params: {
      supplier: attributes_for(:supplier).merge(currency_id: currency.id,
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
    contact = supplier.contacts.create!(name: 'Original')
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

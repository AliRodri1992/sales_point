# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier contact integration', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  it 'creates, normalizes and displays a supplier contact' do
    post admin_supplier_contacts_path(supplier),
         params: { contact: { name: 'Operations', email: 'OPS@EXAMPLE.COM', phone: '5512345678' } }

    expect(response).to redirect_to(admin_supplier_contacts_path(supplier))
    contact = supplier.contacts.last
    expect(contact.email).to eq('ops@example.com')
    expect(contact.phone).to start_with('+52')

    get admin_supplier_path(supplier, tab: 'contacts')
    expect(response.body).to include('Operations')
  end

  it 'hides active status on new contact and forces active on creation' do
    get new_admin_supplier_contact_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('name="contact[active]"')

    post admin_supplier_contacts_path(supplier), params: { contact: { name: 'Operations', active: '0' } }

    expect(response).to redirect_to(admin_supplier_contacts_path(supplier))
    expect(supplier.contacts.last).to be_active
  end

  it 'preserves entered values and displays field errors for invalid email' do
    post admin_supplier_contacts_path(supplier),
         params: { contact: { name: 'Operations', email: 'invalid-email' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('invalid-email')
    expect(response.body).to include('data-server-field-error')
  end
end

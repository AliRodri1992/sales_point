# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organization contacts', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: admin_role)
    sign_in user
  end

  it 'creates contacts for the signed-in organization' do
    post admin_organization_contacts_path, params: { contact: { name: 'Owner', primary: true } }
    expect(response).to have_http_status(:redirect)
    expect(organization.contacts.last.name).to eq('Owner')
  end

  it 'does not allow changing a contact from another organization' do
    foreign_contact = create(:contact, contactable: create(:organization))
    patch admin_organization_contact_path(foreign_contact), params: { contact: { name: 'Changed' } }
    expect(response).to have_http_status(:not_found)
    expect(foreign_contact.reload.name).not_to eq('Changed')
  end

  it 'soft deletes a contact without removing its row' do
    contact = create(:contact, contactable: organization)
    delete admin_organization_contact_path(contact)
    expect(response).to have_http_status(:redirect)
    expect(contact.reload.deleted_at).to be_present
  end

  it 'forbids contact management if the organization context is missing' do
    allow_any_instance_of(Admin::OrganizationContactsController).to receive(:current_organization).and_return(nil)

    get admin_organization_contacts_path

    expect(response).to have_http_status(:forbidden)
  end

  it 'forbids contact management when the user is not an administrator' do
    allow_any_instance_of(User).to receive(:admin?).and_return(false)

    get admin_organization_contacts_path

    expect(response).to have_http_status(:forbidden)
  end
end

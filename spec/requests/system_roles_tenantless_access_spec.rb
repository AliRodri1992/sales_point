# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tenantless role authorization', type: :request do
  let!(:actor) { create(:user, :english) }
  let!(:admin_role) { create(:system_role, :system, code: 'administrator') }

  before do
    create(:user_role, user: actor, system_role: admin_role)
    sign_in actor
  end

  it 'does not grant role, catalog or administration access without an organization' do
    get admin_categories_path
    expect(response).to have_http_status(:forbidden)
    get admin_languages_path
    expect(response).to have_http_status(:forbidden)
    get system_roles_path
    expect(response).to have_http_status(:forbidden)

    CurrentOrganizationAccess.set(organization: nil, enforce_tenant: true) do
      expect(actor.admin?).to be(false)
      expect(actor.role?('administrator')).to be(false)
    end
  end

  it 'revokes an existing session when the last membership was archived' do
    organization = create(:organization)
    membership = create(:organization_membership, user: actor, organization:)
    membership.update!(deleted_at: Time.current)

    get system_roles_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

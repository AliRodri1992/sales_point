# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User permissions are isolated to the selected organization', type: :request do
  it 'does not carry a system role grant into another organization with active membership' do
    first_org = create(:organization)
    second_org = create(:organization)
    actor = create(:user)
    role = create(:system_role, :system, code: 'tenant_specific_users_role')
    create(:organization_membership, user: actor, organization: first_org)
    create(:organization_membership, user: actor, organization: second_org)
    create(:user_role, user: actor, system_role: role, organization: first_org)

    %w[users.access users.index].each do |code|
      permission = Permission.find_or_create_by!(code:) do |record|
        record.name = code
        record.module_name = 'Usuarios'
        record.status = :active
      end
      create(:system_role_permission, system_role: role, permission:)
    end

    sign_in actor
    get admin_users_path
    expect(response).to have_http_status(:ok)

    patch admin_select_organization_path(second_org)
    expect(response).to redirect_to(admin_dashboard_path)
    get admin_users_path
    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects a user directory request from a foreign branch role after changing organizations' do
    first_org = create(:organization)
    second_org = create(:organization)
    branch = create(:branch, organization: first_org, operational_state: 'active')
    role = create(:system_role, :branch)
    actor = create(:user)
    create(:organization_membership, user: actor, organization: first_org)
    create(:organization_membership, user: actor, organization: second_org)
    create(:user_role, user: actor, system_role: role, branch:)
    %w[users.access users.index].each do |code|
      permission = Permission.find_or_create_by!(code:) do |p|
        p.name = code
        p.module_name = 'Usuarios'
        p.status = :active
      end
      create(:system_role_permission, system_role: role, permission:)
    end

    sign_in actor
    get admin_users_path
    expect(response).to have_http_status(:ok)

    patch admin_select_organization_path(second_org)
    expect(response).to redirect_to(admin_dashboard_path)
    get admin_users_path
    expect(response).to have_http_status(:forbidden)
  end
end

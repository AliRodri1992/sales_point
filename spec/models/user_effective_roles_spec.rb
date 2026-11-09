# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create(:user) }
  let(:branch_role) { create(:system_role, :branch, code: 'effective_branch_access') }
  let(:permission) do
    Permission.find_or_create_by!(code: 'users.access') do |record|
      record.name = 'Access users'
      record.module_name = 'Usuarios'
      record.status = :active
    end
  end

  before { SystemRolePermission.find_or_create_by!(system_role: branch_role, permission:) }

  it 'does not grant permissions from a branch still in preparation' do
    branch = create(:branch, operational_state: 'preparing')
    create(:user_role, user:, branch:, system_role: branch_role)

    expect(user.role?('effective_branch_access', branch:)).to be(false)
    expect(user.permission?('users.access')).to be(false)
  end

  it 'grants assigned permissions when the branch is operational' do
    branch = create(:branch, operational_state: 'active')
    create(:user_role, user:, branch:, system_role: branch_role)

    expect(user.role?('effective_branch_access', branch:)).to be(true)
    expect(user.permission?('users.access')).to be(true)
  end

  it 'does not carry branch-granted permissions into another organization' do
    first_org = create(:organization)
    second_org = create(:organization)
    create(:organization_membership, user:, organization: first_org)
    first = create(:branch, organization: first_org, operational_state: 'active')
    create(:user_role, user:, branch: first, system_role: branch_role)

    expect(user.permission?('users.access', organization: first_org)).to be(true)
    expect(user.permission?('users.access', organization: second_org)).to be(false)
    expect(user.role?('effective_branch_access', organization: second_org)).to be(false)
    expect(user.effective_permission_codes(organization: second_org)).not_to include('users.access')
  end

  it 'does not grant a global role in an organization without an accessible membership' do
    first_org = create(:organization)
    second_org = create(:organization)
    create(:organization_membership, user:, organization: first_org)
    system_role = create(:system_role, :system, code: 'effective_tenant_global_role')
    create(:user_role, user:, system_role:)
    create(:system_role_permission, system_role:, permission:)

    expect(user.role?('effective_tenant_global_role', organization: first_org)).to be(true)
    expect(user.permission?('users.access', organization: first_org)).to be(true)
    expect(user.role?('effective_tenant_global_role', organization: second_org)).to be(false)
    expect(user.permission?('users.access', organization: second_org)).to be(false)
    expect(user.effective_permission_codes(organization: second_org)).to be_empty
  end

  it 'does not grant a global role when the organization membership is suspended' do
    organization = create(:organization)
    create(:organization_membership, user:, organization:, account_status: :suspended)
    system_role = create(:system_role, :system, code: 'effective_suspended_role')
    create(:user_role, user:, system_role:)

    expect(user.role?('effective_suspended_role', organization:)).to be(false)
  end

  it 'does not inherit an organization-specific administrator role when joining another organization' do
    first_org = create(:organization)
    second_org = create(:organization)
    create(:organization_membership, user:, organization: first_org)
    system_role = create(:system_role, :system, code: 'effective_company_admin')
    first_grant = create(:user_role, user:, system_role:, organization: first_org)

    create(:organization_membership, user:, organization: second_org)

    expect(user.role?('effective_company_admin', organization: first_org)).to be(true)
    expect(user.role?('effective_company_admin', organization: second_org)).to be(false)

    second_grant = create(:user_role, user:, system_role:, organization: second_org)
    expect(user.role?('effective_company_admin', organization: second_org)).to be(true)

    second_grant.update!(deleted_at: Time.current)
    expect(user.role?('effective_company_admin', organization: second_org)).to be(false)
    expect(first_grant.reload.deleted_at).to be_nil
    expect(user.role?('effective_company_admin', organization: first_org)).to be(true)
  end

  it 'shows only the selected organization role name' do
    first_org = create(:organization)
    second_org = create(:organization)
    create(:organization_membership, user:, organization: first_org)
    create(:organization_membership, user:, organization: second_org)
    first_role = create(:system_role, :system, code: 'tenant_role_alpha', name: 'Alpha Role')
    second_role = create(:system_role, :system, code: 'tenant_role_beta', name: 'Beta Role')
    create(:user_role, user:, system_role: first_role, organization: first_org)
    create(:user_role, user:, system_role: second_role, organization: second_org)

    CurrentOrganizationAccess.set(organization: first_org) do
      expect(user.display_role_name).to eq('Alpha Role')
    end
    CurrentOrganizationAccess.set(organization: second_org) do
      expect(user.display_role_name).to eq('Beta Role')
    end
  end

  it 'keeps a valid global role available independently of branch state' do
    system_role = create(:system_role, :system, code: 'effective_global_role')
    create(:user_role, user:, system_role:)

    expect(user.role?('effective_global_role')).to be(true)
  end
end

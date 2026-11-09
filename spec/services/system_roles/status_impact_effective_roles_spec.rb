# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRoles::StatusImpact do
  let(:user) { create(:user) }
  let(:role) { create(:system_role, :system, code: 'seasonal_operations') }
  let(:other) { create(:system_role, :system, code: 'alternative_operations') }
  let(:permission) { create(:permission, code: 'operations.read') }

  it 'does not count an alternate role on a non-operational branch as effective access' do
    branch_role = create(:system_role, :branch, code: 'branch_staff')
    branch = create(:branch, operational_state: 'preparing')
    create(:organization_membership, user:, organization: branch.organization)
    create(:user_role, user:, system_role: role)
    create(:system_role_permission, system_role: branch_role, permission:)
    create(:user_role, user:, system_role: branch_role, branch:)

    expect(described_class.new(role).counts[:without_other_roles]).to eq(1)
  end

  it 'does not treat a permissionless role as an effective alternative' do
    organization = create(:organization)
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: role, organization:)
    create(:user_role, user:, system_role: other, organization:)

    expect(described_class.new(role).counts[:without_other_roles]).to eq(1)
  end

  it 'does not use a role from another tenant to reduce the impact count' do
    local = create(:organization)
    foreign = create(:organization)
    create(:organization_membership, organization: local, user:)
    create(:organization_membership, organization: foreign, user:)
    create(:system_role_permission, system_role: other, permission:)
    create(:user_role, user:, system_role: role, organization: local)
    create(:user_role, user:, system_role: other, organization: foreign)

    expect(described_class.new(role).counts[:without_other_roles]).to eq(1)
  end

  it 'accepts an effective alternative in the same accessible organization' do
    organization = create(:organization)
    create(:organization_membership, organization:, user:)
    create(:system_role_permission, system_role: other, permission:)
    create(:user_role, user:, system_role: role, organization:)
    create(:user_role, user:, system_role: other, organization:)

    expect(described_class.new(role).counts[:without_other_roles]).to eq(0)
  end
end

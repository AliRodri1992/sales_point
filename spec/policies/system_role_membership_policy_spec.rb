# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRolePolicy do
  it 'blocks edits and lifecycle changes for a role assigned in another organization' do
    admin = create(:user)
    own = create(:organization)
    other = create(:organization)
    create(:organization_membership, user: admin, organization: own)
    super_role = create(:system_role, :system, code: 'super_admin')
    create(:user_role, user: admin, system_role: super_role, organization: own)
    shared = create(:system_role, :system, code: 'shared_store')
    other_user = create(:user)
    create(:organization_membership, user: other_user, organization: other)
    create(:user_role, user: other_user, system_role: shared, organization: other)

    CurrentOrganizationAccess.set(organization: own) do
      policy = described_class.new(admin, shared)
      expect(policy.show?).to be(true)
      expect(policy.update?).to be(false)
      expect(policy.update_permissions?).to be(false)
      expect(policy.change_status?).to be(false)
      expect(policy.audit_history?).to be(false)
    end
  end

  it 'requires an accessible tenant membership for every administrative action' do
    user = create(:user)
    organization = create(:organization)
    membership = create(:organization_membership, user:, organization:)
    create(:user_role, user:, organization:, system_role: create(:system_role, :system, code: 'super_admin'))
    role = build(:system_role)

    expect(described_class.new(user, role).create?).to be(true)
    membership.update!(status: :inactive)

    policy = described_class.new(user, role)
    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.create?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.change_status?).to be(false)
  end

  it 'does not allow a superadmin role in one tenant to administer another' do
    user = create(:user)
    first = create(:organization)
    second = create(:organization)
    create(:organization_membership, user:, organization: first)
    create(:organization_membership, user:, organization: second)
    create(:user_role, user:, organization: first, system_role: create(:system_role, :system, code: 'super_admin'))

    CurrentOrganizationAccess.set(organization: second) do
      expect(described_class.new(user, build(:system_role)).create?).to be(false)
    end
    CurrentOrganizationAccess.set(organization: first) do
      expect(described_class.new(user, build(:system_role)).create?).to be(true)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRolePolicy do
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

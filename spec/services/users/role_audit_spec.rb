# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users role change audit' do
  let(:organization) { create(:organization) }
  let(:actor) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:target) { create(:user, user_type: :customer) }

  before do
    create(:organization_membership, user: actor, organization:)
    create(:organization_membership, user: target, organization:)
  end

  it 'records grants and revocations with actor and organization' do
    role = create(:system_role, :system, code: 'role_audit_basic')

    expect do
      Users::AdminAccountWriter.new(
        user: target, organization:, actor:, attributes: { system_role_ids: [role.id.to_s] }
      ).save
    end.to change(UserRoleAuditEvent, :count).by(1)

    audit = UserRoleAuditEvent.last
    expect(audit).to have_attributes(user: target, organization:, actor:, system_role: role, action: 'granted')

    expect do
      Users::AdminAccountWriter.new(
        user: target, organization:, actor:, attributes: { system_role_ids: [] }
      ).save
    end.to change(UserRoleAuditEvent, :count).by(1)

    expect(UserRoleAuditEvent.last).to have_attributes(
      user: target, organization:, actor:, system_role: role, action: 'revoked'
    )
  end

  it 'attributes branch grants to the selected organization' do
    branch = create(:branch, organization:, operational_state: 'active')
    role = create(:system_role, :branch, code: 'role_audit_branch')

    result = Users::AdminAccountWriter.new(
      user: target, organization:, actor:,
      attributes: { branch_role_assignments: ["#{branch.id}:#{role.id}"] }
    ).save

    expect(result).to be(true)
    expect(UserRoleAuditEvent.last).to have_attributes(
      organization:, actor:, branch:, system_role: role, action: 'granted'
    )
  end
end

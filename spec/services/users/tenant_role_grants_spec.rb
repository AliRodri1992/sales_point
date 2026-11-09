# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organization-specific system role updates' do
  it 'changes roles in one company without revoking a shared account role in another' do
    first_org = create(:organization)
    second_org = create(:organization)
    target = create(:user, user_type: :customer)
    create(:organization_membership, user: target, organization: first_org)
    create(:organization_membership, user: target, organization: second_org)
    first_role = create(:system_role, :system, code: 'tenant_first_staff')
    second_role = create(:system_role, :system, code: 'tenant_second_staff')
    create(:user_role, user: target, system_role: first_role, organization: first_org)

    writer = Users::AdminAccountWriter.new(
      user: target, organization: second_org, attributes: { system_role_ids: [second_role.id] }
    )
    expect(writer.save).to be(true)
    expect(target.user_roles.active.where(organization: first_org).pluck(:system_role_id)).to eq([first_role.id])
    expect(target.user_roles.active.where(organization: second_org).pluck(:system_role_id)).to eq([second_role.id])

    removal = Users::AdminAccountWriter.new(
      user: target, organization: second_org, attributes: { system_role_ids: [] }
    )
    expect(removal.save).to be(true)
    expect(target.user_roles.active.where(organization: second_org)).to be_empty
    expect(target.user_roles.active.where(organization: first_org).pluck(:system_role_id)).to eq([first_role.id])
  end
end

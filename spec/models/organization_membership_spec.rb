# frozen_string_literal: true

RSpec.describe OrganizationMembership, type: :model do
  subject(:membership) { build(:organization_membership) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:user) }

  it 'does not grant previously unscoped roles when the first organization is joined' do
    user = create(:user)
    role = create(:system_role, :system, code: 'orphan_membership_role')
    assignment = create(:user_role, user:, system_role: role)
    organization = create(:organization)

    create(:organization_membership, user:, organization:)

    expect(assignment.reload.organization_id).to be_nil
    expect(user.role?('orphan_membership_role', organization:)).to be(false)
  end

  it 'defines the supported statuses' do
    expect(described_class.statuses).to include(
      'active' => 'active',
      'inactive' => 'inactive'
    )
  end
end

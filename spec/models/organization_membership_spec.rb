# frozen_string_literal: true

RSpec.describe OrganizationMembership, type: :model do
  subject(:membership) { build(:organization_membership) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:user) }

  it 'materializes a preassigned role for the first organization only' do
    user = create(:user)
    role = create(:system_role, :system, code: 'preassigned_membership_role')
    assignment = create(:user_role, user:, system_role: role)
    organization = create(:organization)

    create(:organization_membership, user:, organization:)
    other = create(:organization)
    create(:organization_membership, user:, organization: other)

    expect(assignment.reload.organization_id).to eq(organization.id)
    expect(user.role?('preassigned_membership_role', organization:)).to be(true)
    expect(user.role?('preassigned_membership_role', organization: other)).to be(false)
  end

  it 'defines the supported statuses' do
    expect(described_class.statuses).to include(
      'active' => 'active',
      'inactive' => 'inactive'
    )
  end
end

# frozen_string_literal: true

RSpec.describe OrganizationMembership, type: :model do
  subject(:membership) { build(:organization_membership) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:user) }

  it 'defines the supported statuses' do
    expect(described_class.statuses).to include(
      'active' => 'active',
      'inactive' => 'inactive'
    )
  end
end

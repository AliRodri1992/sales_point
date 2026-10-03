# frozen_string_literal: true

RSpec.describe OrganizationMembership, type: :model do
  subject(:membership) { build(:organization_membership) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:user) }
  it { is_expected.to define_enum_for(:status).with_values(active: 'active', inactive: 'inactive') }
end
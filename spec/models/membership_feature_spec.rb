# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipFeature, type: :model do
  subject(:feature) { build(:membership_feature) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }

  it 'requires a unique feature key' do
    create(:membership_feature, key: 'max_users')
    duplicate = build(:membership_feature, key: 'max_users')
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:key]).to be_present
  end

  it 'accepts the supported value types' do
    expect(feature).to be_boolean
    expect(build(:membership_feature, value_type: :integer)).to be_integer
    expect(build(:membership_feature, value_type: :decimal)).to be_decimal
    expect(build(:membership_feature, value_type: :text)).to be_text
  end
end

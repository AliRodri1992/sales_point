# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipPlanFeature, type: :model do
  subject(:plan_feature) { build(:membership_plan_feature) }

  it { is_expected.to belong_to(:membership_plan) }
  it { is_expected.to belong_to(:membership_feature) }
  it { is_expected.to validate_numericality_of(:limit).is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }

  it 'does not allow the same feature twice in a plan' do
    plan = create(:membership_plan)
    feature = create(:membership_feature)
    create(:membership_plan_feature, membership_plan: plan, membership_feature: feature)
    duplicate = build(:membership_plan_feature, membership_plan: plan, membership_feature: feature)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:membership_feature_id]).to be_present
  end
end

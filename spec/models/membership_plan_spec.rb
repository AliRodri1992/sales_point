# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipPlan, type: :model do
  subject(:plan) { build(:membership_plan) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:slug) }
  it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_length_of(:currency).is_equal_to(3) }

  it 'accepts monthly and yearly billing intervals' do
    expect(plan).to be_monthly
    expect(build(:membership_plan, billing_interval: :yearly)).to be_yearly
  end

  it 'rejects duplicate slugs' do
    create(:membership_plan, slug: 'professional')
    duplicate = build(:membership_plan, slug: 'professional')
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:slug]).to be_present
  end

  it 'exposes only active plan features through membership_features' do
    plan.save!
    active_feature = create(:membership_feature, key: 'pos')
    deleted_feature = create(:membership_feature, key: 'reports')
    create(:membership_plan_feature, membership_plan: plan, membership_feature: active_feature)
    create(:membership_plan_feature, membership_plan: plan, membership_feature: deleted_feature, deleted_at: Time.current)

    expect(plan.membership_features).to contain_exactly(active_feature)
  end
end

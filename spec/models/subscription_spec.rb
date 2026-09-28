# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscription, type: :model do
  subject(:subscription) { build(:subscription) }

  it { is_expected.to validate_presence_of(:starts_at) }

  it 'allows only one current subscription for an organization' do
    organization = create(:organization)
    create(:subscription, organization:)

    duplicate = build(:subscription, organization:)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:organization]).to be_present
  end

  it 'calculates remaining trial days' do
    subscription = build(:subscription, status: :trialing, trial_ends_at: 3.days.from_now)

    expect(subscription.trial_days_remaining).to eq(3)
  end

  it 'reads a plan feature and its limit' do
    plan = create(:membership_plan)
    feature = create(:membership_feature, key: 'max_users', value_type: :integer)
    create(:membership_plan_feature, membership_plan: plan, membership_feature: feature, limit: 10)

    subscription = build(:subscription, membership_plan: plan)

    expect(subscription.limit_for('max_users')).to eq(10)
    expect(subscription.limit_reached?('max_users', 10)).to be(true)
  end
end

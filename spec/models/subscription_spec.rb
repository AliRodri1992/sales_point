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

  describe 'trial lifecycle states' do
    it 'handles absent, expired and future trials' do
      trial = build(:subscription, status: :trialing, trial_ends_at: nil)
      expect(trial).to be_active_or_trialing
      expect(trial).not_to be_trial
      expect(trial).not_to be_trial_expired
      expect(trial.trial_days_remaining).to eq(0)

      trial.starts_at = 4.days.ago
      trial.trial_ends_at = 1.day.ago
      expect(trial).to be_trial_expired
      expect(trial.trial_days_remaining).to eq(0)

      trial.trial_ends_at = 2.days.from_now
      expect(trial).not_to be_trial_expired
      expect(trial.trial_days_remaining).to eq(2)

      trial.status = :canceled
      expect(trial).not_to be_active_or_trialing
      expect(trial).not_to be_trial
    end
  end

  describe 'plan feature entitlements' do
    it 'recognizes enabled, disabled and missing feature assignments' do
      plan = create(:membership_plan)
      enabled_feature = create(:membership_feature, key: 'reports')
      disabled_feature = create(:membership_feature, key: 'api')
      create(:membership_plan_feature, membership_plan: plan, membership_feature: enabled_feature, enabled: true)
      create(:membership_plan_feature, membership_plan: plan, membership_feature: disabled_feature, enabled: false)
      membership = build(:subscription, membership_plan: plan)

      expect(membership.feature_enabled?('reports')).to be(true)
      expect(membership.feature_enabled?('api')).to be(false)
      expect(membership.feature_enabled?('missing_feature')).to be_nil
      expect(membership.limit_for('missing_feature')).to be_nil
      expect(membership.unlimited?('missing_feature')).to be(false)
      expect(membership.limit_reached?('missing_feature', 100)).to be(false)
    end

    it 'enforces finite limits and recognizes explicitly unlimited quotas' do
      plan = create(:membership_plan)
      feature = create(:membership_feature, key: 'max_branches', value_type: :integer)
      assignment = create(:membership_plan_feature, membership_plan: plan, membership_feature: feature,
                                                    limit: 3, value: nil)
      membership = build(:subscription, membership_plan: plan)

      expect(membership.limit_reached?('max_branches', 2)).to be(false)
      expect(membership.limit_reached?('max_branches', 3)).to be(true)

      assignment.update!(limit: nil, value: 'unlimited')
      expect(membership.unlimited?('max_branches')).to be(true)
      expect(membership.limit_reached?('max_branches', 999)).to be(false)
    end
  end

  it 'permits canceled subscriptions to coexist with an active subscription' do
    organization = create(:organization)
    create(:subscription, organization:)
    canceled = build(:subscription, organization:, status: :canceled)

    expect(canceled).to be_valid
  end

end

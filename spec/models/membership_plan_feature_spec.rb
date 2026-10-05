# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipPlanFeature, type: :model do
  subject(:plan_feature) { build(:membership_plan_feature) }

  describe 'associations' do
    it { is_expected.to belong_to(:membership_plan) }
    it { is_expected.to belong_to(:membership_feature) }
  end

  describe 'validations' do
    it do
      is_expected.to validate_uniqueness_of(:membership_feature_id)
        .scoped_to(:membership_plan_id)
    end

    it do
      is_expected.to validate_numericality_of(:limit)
        .only_integer
        .is_greater_than_or_equal_to(0)
        .allow_nil
    end

    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

    it 'accepts a valid plan feature' do
      expect(plan_feature).to be_valid
    end

    it 'rejects a negative limit' do
      plan_feature.limit = -1

      expect(plan_feature).to be_invalid
      expect(plan_feature.errors[:limit]).to be_present
    end

    it 'rejects a negative position' do
      plan_feature.position = -1

      expect(plan_feature).to be_invalid
      expect(plan_feature.errors[:position]).to be_present
    end
  end

  describe 'uniqueness' do
    it 'rejects assigning the same feature twice to a plan' do
      existing = create(:membership_plan_feature)

      duplicate = build(
        :membership_plan_feature,
        membership_plan: existing.membership_plan,
        membership_feature: existing.membership_feature
      )

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:membership_feature_id]).to be_present
    end
  end
end

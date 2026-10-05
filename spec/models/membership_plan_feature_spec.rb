# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipPlanFeature, type: :model do
  subject(:plan_feature) do
    build(
      :membership_plan_feature,
      membership_plan: build(:membership_plan),
      membership_feature: build(:membership_feature),
      limit: nil,
      position: 0
    )
  end

  describe 'associations' do
    it 'belongs to a membership plan' do
      association = described_class.reflect_on_association(:membership_plan)

      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to a membership feature' do
      association = described_class.reflect_on_association(:membership_feature)

      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(plan_feature).to be_valid
    end

    it 'rejects a duplicate feature within the same plan' do
      existing = create(:membership_plan_feature)

      duplicate = build(
        :membership_plan_feature,
        membership_plan: existing.membership_plan,
        membership_feature: existing.membership_feature
      )

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:membership_feature_id]).to be_present
    end

    it 'allows the same feature in a different plan' do
      feature = create(:membership_feature)
      first_plan = create(:membership_plan)
      second_plan = create(:membership_plan)

      create(:membership_plan_feature, membership_plan: first_plan, membership_feature: feature)
      replacement = build(
        :membership_plan_feature,
        membership_plan: second_plan,
        membership_feature: feature
      )

      expect(replacement).to be_valid
    end

    it 'allows a nil limit' do
      plan_feature.limit = nil

      expect(plan_feature).to be_valid
    end

    it 'rejects a negative limit' do
      plan_feature.limit = -1

      expect(plan_feature).to be_invalid
      expect(plan_feature.errors[:limit]).to be_present
    end

    it 'rejects a non-integer limit' do
      plan_feature.limit = 'not-an-integer'

      expect(plan_feature).to be_invalid
      expect(plan_feature.errors[:limit]).to be_present
    end

    it 'rejects a negative position' do
      plan_feature.position = -1

      expect(plan_feature).to be_invalid
      expect(plan_feature.errors[:position]).to be_present
    end

    it 'rejects a non-integer position' do
      plan_feature.position = 'not-an-integer'

      expect(plan_feature).to be_invalid
      expect(plan_feature.errors[:position]).to be_present
    end
  end
end

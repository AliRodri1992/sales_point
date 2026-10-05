# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipFeature, type: :model do
  subject(:feature) { build(:membership_feature) }

  describe 'associations' do
    it { is_expected.to have_many(:membership_plan_features).dependent(:destroy) }
    it { is_expected.to have_many(:membership_plans).through(:membership_plan_features) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(150) }
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_uniqueness_of(:key) }
    it { is_expected.to validate_format_of(:key).with_regex(/\A[a-z0-9]+(?:_[a-z0-9]+)*\z/) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

    it 'accepts a valid feature' do
      expect(feature).to be_valid
    end

    it 'rejects a key with invalid format' do
      feature.key = 'Invalid Key'

      expect(feature).to be_invalid
      expect(feature.errors[:key]).to be_present
    end

    it 'rejects a negative position' do
      feature.position = -1

      expect(feature).to be_invalid
      expect(feature.errors[:position]).to be_present
    end
  end

  describe 'enums' do
    it do
      expect(described_class).to define_enum_for(:value_type)
        .with_values(boolean: 'boolean', integer: 'integer', decimal: 'decimal', text: 'text')
    end
  end
end

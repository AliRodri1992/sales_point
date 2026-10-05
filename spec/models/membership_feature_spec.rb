# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipFeature, type: :model do
  subject(:feature) { build(:membership_feature) }

  describe 'associations' do
    it 'has many membership plan features with dependent destroy' do
      association = described_class.reflect_on_association(:membership_plan_features)

      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it 'has many membership plans through membership plan features' do
      association = described_class.reflect_on_association(:membership_plans)

      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:membership_plan_features)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(feature).to be_valid
    end

    it 'requires a name' do
      feature.name = nil

      expect(feature).to be_invalid
      expect(feature.errors[:name]).to be_present
    end

    it 'rejects names shorter than two characters' do
      feature.name = 'A'

      expect(feature).to be_invalid
      expect(feature.errors[:name]).to be_present
    end

    it 'rejects names longer than 150 characters' do
      feature.name = 'A' * 151

      expect(feature).to be_invalid
      expect(feature.errors[:name]).to be_present
    end

    it 'requires a key' do
      feature.key = nil

      expect(feature).to be_invalid
      expect(feature.errors[:key]).to be_present
    end

    it 'rejects duplicate keys' do
      create(:membership_feature, key: 'catalog_access')
      duplicate = build(:membership_feature, key: 'catalog_access')

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:key]).to be_present
    end

    it 'rejects an invalid key format' do
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
    it 'defines the supported value types' do
      expect(described_class.value_types).to eq(
        'boolean' => 'boolean',
        'integer' => 'integer',
        'decimal' => 'decimal',
        'text' => 'text'
      )
    end
  end
end

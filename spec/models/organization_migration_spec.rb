# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizationMigration, type: :model do
  subject(:migration) { build(:organization_migration) }

  describe 'associations' do
    it 'belongs to an organization' do
      association = described_class.reflect_on_association(:organization)

      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(migration).to be_valid
    end

    it 'requires volume' do
      migration.volume = nil

      expect(migration).to be_invalid
      expect(migration.errors[:volume]).to be_present
    end

    it 'requires priority' do
      migration.priority = nil

      expect(migration).to be_invalid
      expect(migration.errors[:priority]).to be_present
    end

    it 'requires status' do
      migration.status = nil

      expect(migration).to be_invalid
      expect(migration.errors[:status]).to be_present
    end

    it 'allows only one migration per organization' do
      organization = create(:organization)
      create(:organization_migration, organization:)
      duplicate = build(:organization_migration, organization:)

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:organization_id]).to be_present
    end
  end

  describe 'enums' do
    it 'defines the supported volumes' do
      expect(described_class.volumes).to eq(
        'small' => 'under_500',
        'medium' => '500_5000',
        'large' => 'over_5000'
      )
    end

    it 'defines the supported priorities' do
      expect(described_class.priorities).to eq(
        'catalog' => 'catalog',
        'inventory' => 'inventory',
        'customers' => 'customers',
        'everything' => 'all'
      )
    end

    it 'defines the supported statuses' do
      expect(described_class.statuses).to eq(
        'pending' => 'pending',
        'in_progress' => 'in_progress',
        'completed' => 'completed'
      )
    end
  end
end

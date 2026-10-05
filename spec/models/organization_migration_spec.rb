# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizationMigration, type: :model do
  subject(:migration) { build(:organization_migration) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:volume) }
    it { is_expected.to validate_presence_of(:priority) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_uniqueness_of(:organization_id) }

    it 'accepts a valid migration' do
      expect(migration).to be_valid
    end

    it 'rejects a second migration for the same organization' do
      organization = create(:organization)
      create(:organization_migration, organization:)

      duplicate = build(:organization_migration, organization:)

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:organization_id]).to be_present
    end
  end

  describe 'enums' do
    it do
      expect(described_class).to define_enum_for(:volume)
        .with_values(small: 'under_500', medium: '500_5000', large: 'over_5000')
    end

    it do
      expect(described_class).to define_enum_for(:priority)
        .with_values(catalog: 'catalog', inventory: 'inventory', customers: 'customers', everything: 'all')
    end

    it do
      expect(described_class).to define_enum_for(:status)
        .with_values(pending: 'pending', in_progress: 'in_progress', completed: 'completed')
    end
  end
end

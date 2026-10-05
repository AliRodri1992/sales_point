# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Permission, type: :model do
  subject(:permission) { build(:permission) }

  describe 'associations' do
    it { is_expected.to have_many(:system_role_permissions).dependent(:destroy) }
    it { is_expected.to have_many(:system_roles).through(:system_role_permissions) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_length_of(:code).is_at_most(80) }
    it { is_expected.to validate_format_of(:code).with_regex(/\A[a-z0-9_.]+\z/) }
    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(80) }
    it { is_expected.to validate_presence_of(:module_name) }
    it { is_expected.to validate_length_of(:module_name).is_at_most(50) }
    it { is_expected.to validate_presence_of(:status) }

    it 'accepts a valid permission' do
      expect(permission).to be_valid
    end

    it 'rejects an invalid code' do
      permission.code = 'Invalid Permission'

      expect(permission).to be_invalid
      expect(permission.errors[:code]).to be_present
    end
  end

  describe 'enums' do
    it do
      expect(described_class).to define_enum_for(:status)
        .with_values(active: 'active', inactive: 'inactive')
    end
  end

  describe '.available' do
    it 'returns active permissions ordered by module and name' do
      inactive = create(:permission, module_name: 'Sales', name: 'Create', status: :inactive)
      active_z = create(:permission, module_name: 'Sales', name: 'Update')
      active_a = create(:permission, module_name: 'Catalog', name: 'View')

      expect(described_class.available).to eq([active_a, active_z])
      expect(described_class.available).not_to include(inactive)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Permission, type: :model do
  subject(:permission) { build(:permission) }

  describe 'associations' do
    it 'has many system role permissions with dependent destroy' do
      association = described_class.reflect_on_association(:system_role_permissions)

      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it 'has many system roles through system role permissions' do
      association = described_class.reflect_on_association(:system_roles)

      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:system_role_permissions)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(permission).to be_valid
    end

    it 'requires a code' do
      permission.code = nil

      expect(permission).to be_invalid
      expect(permission.errors[:code]).to be_present
    end

    it 'rejects codes longer than 80 characters' do
      permission.code = 'a' * 81

      expect(permission).to be_invalid
      expect(permission.errors[:code]).to be_present
    end

    it 'rejects codes with invalid characters' do
      permission.code = 'Invalid Permission'

      expect(permission).to be_invalid
      expect(permission.errors[:code]).to be_present
    end

    it 'rejects duplicate codes' do
      create(:permission, code: 'catalog.access')
      duplicate = build(:permission, code: 'catalog.access')

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:code]).to be_present
    end

    it 'requires a name' do
      permission.name = nil

      expect(permission).to be_invalid
      expect(permission.errors[:name]).to be_present
    end

    it 'rejects names longer than 80 characters' do
      permission.name = 'a' * 81

      expect(permission).to be_invalid
      expect(permission.errors[:name]).to be_present
    end

    it 'requires a module name' do
      permission.module_name = nil

      expect(permission).to be_invalid
      expect(permission.errors[:module_name]).to be_present
    end

    it 'rejects module names longer than 50 characters' do
      permission.module_name = 'a' * 51

      expect(permission).to be_invalid
      expect(permission.errors[:module_name]).to be_present
    end

    it 'requires a status' do
      permission.status = nil

      expect(permission).to be_invalid
      expect(permission.errors[:status]).to be_present
    end
  end

  describe 'enums' do
    it 'defines the supported statuses' do
      expect(described_class.statuses).to eq('active' => 'active', 'inactive' => 'inactive')
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

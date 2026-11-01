# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRolePermission, type: :model do
  subject(:role_permission) { build(:system_role_permission) }

  describe 'associations' do
    it 'belongs to a system role' do
      association = described_class.reflect_on_association(:system_role)

      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to a permission' do
      association = described_class.reflect_on_association(:permission)

      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(role_permission).to be_valid
    end

    it 'rejects assigning the same permission twice to a role' do
      existing = create(:system_role_permission)
      duplicate = build(
        :system_role_permission,
        system_role: existing.system_role,
        permission: existing.permission
      )

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:permission_id]).to be_present
    end
  end
end

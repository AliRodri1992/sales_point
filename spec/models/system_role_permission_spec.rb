# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRolePermission, type: :model do
  subject(:role_permission) { build(:system_role_permission) }

  describe 'associations' do
    it { is_expected.to belong_to(:system_role) }
    it { is_expected.to belong_to(:permission) }
  end

  describe 'validations' do
    it do
      is_expected.to validate_uniqueness_of(:permission_id)
        .scoped_to(:system_role_id)
    end

    it 'accepts a valid role permission' do
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

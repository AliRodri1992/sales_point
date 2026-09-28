require 'rails_helper'

RSpec.describe User, type: :model do
  describe '#permission?' do
    let(:user) { create(:user) }
    let(:role) { create(:system_role, :system, code: 'administrator') }
    let(:permission) { create(:permission, code: 'categories.access') }

    before do
      create(:user_role, user:, system_role: role)
    end

    it 'is true when an active role has the active permission' do
      create(:system_role_permission, system_role: role, permission:)

      expect(user.permission?('categories.access')).to be(true)
    end

    it 'is false for an administrator role after the permission is removed' do
      expect(user.permission?('categories.access')).to be(false)
    end

    it 'is false when the permission is inactive' do
      permission.update!(status: :inactive)
      create(:system_role_permission, system_role: role, permission:)

      expect(user.permission?('categories.access')).to be(false)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::AccountRestoration do
  let(:organization) { create(:organization) }
  let(:super_role) { create(:system_role, :system, code: 'super_admin') }
  let(:administrator) { create(:user, system_roles: [super_role]) }
  let(:user) { create(:user, status: :deleted, deleted_at: Time.current) }

  before do
    permission = Permission.find_or_create_by!(code: 'users.restore') do |item|
      item.name = 'Restore users'
      item.module_name = 'Usuarios'
      item.status = :active
    end
    SystemRolePermission.find_or_create_by!(system_role: super_role, permission:)
    create(:organization_membership, user: administrator, organization:)
    create(:organization_membership, user:, organization:)
  end

  it 'restores only to pending and removes historical role assignments' do
    role = create(:system_role, :system, code: 'cashier')
    user.user_roles.create!(system_role: role)

    described_class.new(user:, actor: administrator, organization:, reason: 'Authorized review').call!

    expect(user.reload).to be_pending
    expect(user.deleted_at).to be_nil
    expect(user.user_roles.active).to be_empty
    expect(UserStatusEvent.where(user:, to_status: 'pending').count).to eq(1)
  end
end

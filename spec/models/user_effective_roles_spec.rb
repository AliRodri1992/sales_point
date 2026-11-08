# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create(:user) }
  let(:branch_role) { create(:system_role, :branch, code: 'effective_branch_access') }
  let(:permission) do
    Permission.find_or_create_by!(code: 'users.access') do |record|
      record.name = 'Access users'
      record.module_name = 'Usuarios'
      record.status = :active
    end
  end

  before { SystemRolePermission.find_or_create_by!(system_role: branch_role, permission:) }

  it 'does not grant permissions from a branch still in preparation' do
    branch = create(:branch, operational_state: 'preparing')
    create(:user_role, user:, branch:, system_role: branch_role)

    expect(user.role?('effective_branch_access', branch:)).to be(false)
    expect(user.permission?('users.access')).to be(false)
  end

  it 'grants assigned permissions when the branch is operational' do
    branch = create(:branch, operational_state: 'active')
    create(:user_role, user:, branch:, system_role: branch_role)

    expect(user.role?('effective_branch_access', branch:)).to be(true)
    expect(user.permission?('users.access')).to be(true)
  end

  it 'keeps a valid global role available independently of branch state' do
    system_role = create(:system_role, :system, code: 'effective_global_role')
    create(:user_role, user:, system_role:)

    expect(user.role?('effective_global_role')).to be(true)
  end
end

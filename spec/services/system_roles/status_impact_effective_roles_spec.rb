# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRoles::StatusImpact do
  it 'does not count alternate roles on non-operational branches as effective access' do
    user = create(:user)
    role = create(:system_role, :system, code: 'seasonal_operations')
    other = create(:system_role, :branch, code: 'branch_staff')
    branch = create(:branch, operational_state: 'preparing')

    create(:user_role, user:, system_role: role)
    create(:user_role, user:, system_role: other, branch:)

    expect(described_class.new(role).counts[:without_other_roles]).to eq(1)
  end
end

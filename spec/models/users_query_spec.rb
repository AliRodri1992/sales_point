# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsersQuery, type: :model do
  let!(:matching_user) { create(:user, email: 'john@example.com', username: 'johnny') }
  let!(:other_user) { create(:user, email: 'jane@example.com', username: 'jane') }
  let(:scope) { User.all }

  it 'returns the scope without filters' do
    expect(described_class.new(scope, {}).call).to include(matching_user, other_user)
  end

  it 'filters by email and username' do
    result = described_class.new(scope, { q: 'john' }).call
    expect(result).to include(matching_user)
    expect(result).not_to include(other_user)
    expect(described_class.new(scope, { q: 'johnny' }).call).to include(matching_user)
  end

  it 'ignores blank search' do
    expect(described_class.new(scope, { q: '   ' }).call).to include(matching_user, other_user)
  end

  it 'filters valid and ignores invalid user types' do
    matching_user.update!(user_type: 'customer')
    expect(described_class.new(scope, { user_type: 'customer' }).call).to include(matching_user)
    expect(described_class.new(scope, { user_type: 'invalid' }).call).to include(matching_user, other_user)
  end

  it 'filters valid and ignores invalid statuses' do
    matching_user.update!(status: 'suspended')
    expect(described_class.new(scope, { status: 'suspended' }).call).to include(matching_user)
    expect(described_class.new(scope, { status: 'invalid' }).call).to include(matching_user, other_user)
  end

  it 'filters by role and ignores blank role' do
    role = create(:system_role, :system, code: 'administrator')
    create(:user_role, user: matching_user, system_role: role)
    expect(described_class.new(scope, { role: role.id }).call).to include(matching_user)
    expect(described_class.new(scope, { role: '' }).call).to include(matching_user, other_user)
  end

  it 'filters organization-local branches and rejects foreign branch filters' do
    organization = create(:organization)
    local = create(:branch, organization:)
    foreign = create(:branch)
    role = create(:system_role, :branch, code: 'store_checkout')
    create(:user_role, user: matching_user, system_role: role, branch: local)
    create(:user_role, user: other_user, system_role: role, branch: foreign)

    expect(described_class.new(scope, { branch: local.id }, organization:).call)
      .to contain_exactly(matching_user)
    expect(described_class.new(scope, { branch: foreign.id }, organization:).call).to be_empty
  end

  it 'matches a branch role on the same assignment when both filters are selected' do
    organization = create(:organization)
    center = create(:branch, organization:)
    north = create(:branch, organization:, name: 'North')
    cashier = create(:system_role, :branch, code: 'cashier_filter')
    supervisor = create(:system_role, :branch, code: 'supervisor_filter')

    create(:user_role, user: matching_user, system_role: cashier, branch: center)
    create(:user_role, user: other_user, system_role: cashier, branch: north)
    create(:user_role, user: other_user, system_role: supervisor, branch: center)

    results = described_class.new(scope, { role: cashier.id, branch: center.id }, organization:).call
    expect(results).to contain_exactly(matching_user)
  end

  it 'never expands the relation supplied by the caller' do
    other_user.update!(username: 'john from another organization')
    restricted = User.where(id: matching_user.id)
    expect(described_class.new(restricted, { q: 'john' }).call).to contain_exactly(matching_user)
  end

  it 'filters the organization account status instead of the global user status' do
    organization = create(:organization)
    create(:organization_membership, organization:, user: matching_user, account_status: :blocked)
    create(:organization_membership, organization:, user: other_user, account_status: :active)
    result = described_class.new(scope, { status: 'blocked' }, organization:).call
    expect(matching_user).to be_active
    expect(result).to contain_exactly(matching_user)
  end
end

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
    result = described_class.new(scope, q: 'john').call
    expect(result).to include(matching_user)
    expect(result).not_to include(other_user)
    expect(described_class.new(scope, q: 'johnny').call).to include(matching_user)
  end

  it 'ignores blank search' do
    expect(described_class.new(scope, q: '   ').call).to include(matching_user, other_user)
  end

  it 'filters valid and ignores invalid user types' do
    matching_user.update!(user_type: 'customer')
    expect(described_class.new(scope, user_type: 'customer').call).to include(matching_user)
    expect(described_class.new(scope, user_type: 'invalid').call).to include(matching_user, other_user)
  end

  it 'filters valid and ignores invalid statuses' do
    matching_user.update!(status: 'suspended')
    expect(described_class.new(scope, status: 'suspended').call).to include(matching_user)
    expect(described_class.new(scope, status: 'invalid').call).to include(matching_user, other_user)
  end

  it 'filters by role and ignores blank role' do
    role = create(:system_role, :system, code: 'administrator')
    create(:user_role, user: matching_user, system_role: role)
    expect(described_class.new(scope, role: role.id).call).to include(matching_user)
    expect(described_class.new(scope, role: '').call).to include(matching_user, other_user)
  end
end

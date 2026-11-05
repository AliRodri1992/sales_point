# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserPolicy::Scope do
  it 'returns no accounts for an anonymous actor' do
    expect(described_class.new(nil, User.all).resolve).to be_empty
  end

  it 'requires both module access and a granular action for ordinary users' do
    role = create(:system_role, :system)
    actor = create(:user, system_roles: [role])
    expect(described_class.new(actor, User.all).resolve).to be_empty
    role.permissions << create(:permission, code: 'users.access')
    expect(described_class.new(actor, User.all).resolve).to be_empty
  end

  it 'keeps the caller relation restricted when a granular user action is allowed' do
    role = create(:system_role, :system)
    actor = create(:user, system_roles: [role])
    %w[users.access users.index].each { |code| role.permissions << create(:permission, code:) }
    allowed = create(:user)
    excluded = create(:user)
    result = described_class.new(actor, User.where(id: allowed.id)).resolve
    expect(result).to contain_exactly(allowed)
    expect(result).not_to include(excluded)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserRole, type: :model do
  subject(:user_role) { build(:user_role) }

  describe 'associations' do
    it 'belongs to a user' do
      association = described_class.reflect_on_association(:user)

      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to a system role' do
      association = described_class.reflect_on_association(:system_role)

      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to an optional branch' do
      association = described_class.reflect_on_association(:branch)

      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be(true)
    end
  end

  describe 'validations' do
    it 'accepts a system role without a branch' do
      role = create(:system_role, :system)
      assignment = build(:user_role, system_role: role, branch: nil)

      expect(assignment).to be_valid
    end

    it 'accepts a branch role with a branch' do
      role = create(:system_role, :branch)
      branch = create(:branch)
      assignment = build(:user_role, system_role: role, branch:)

      expect(assignment).to be_valid
    end

    it 'rejects a branch role without a branch' do
      role = create(:system_role, :branch)
      assignment = build(:user_role, system_role: role, branch: nil)

      expect(assignment).to be_invalid
      expect(assignment.errors[:branch]).to include('is required for branch roles')
    end

    it 'rejects a system role with a branch' do
      role = create(:system_role, :system)
      branch = create(:branch)
      assignment = build(:user_role, system_role: role, branch:)

      expect(assignment).to be_invalid
      expect(assignment.errors[:branch]).to include('must be blank for system roles')
    end

    it 'rejects duplicate active global roles for the same user' do
      user = create(:user)
      role = create(:system_role, :system)
      create(:user_role, user:, system_role: role)
      duplicate = build(:user_role, user:, system_role: role)

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it 'allows the same global role after the existing assignment is soft deleted' do
      user = create(:user)
      role = create(:system_role, :system)
      existing = create(:user_role, user:, system_role: role)
      existing.update!(deleted_at: Time.current)
      replacement = build(:user_role, user:, system_role: role)

      expect(replacement).to be_valid
    end
  end

  describe '.active' do
    it 'returns active assignments for active system roles' do
      user = create(:user)
      active_role = create(:system_role, :system, :active)
      inactive_role = create(:system_role, :system, :inactive)
      active_assignment = create(:user_role, user:, system_role: active_role)
      create(:user_role, user:, system_role: inactive_role)

      expect(described_class.active).to contain_exactly(active_assignment)
    end
  end

  describe 'optional role association in conditional validations' do
    it 'handles a missing system role without raising from conditional validations' do
      assignment = build(:user_role, system_role: nil, branch: nil)

      expect { assignment.valid? }.not_to raise_error
    end
  end
end

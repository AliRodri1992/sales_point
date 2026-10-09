require 'rails_helper'

RSpec.describe BranchPolicy, type: :policy do
  subject(:policy) { described_class.new(user, branch) }

  let(:branch) { create(:branch) }
  let(:other_branch) { create(:branch) }
  let(:system_admin_role) { create(:system_role, :system, code: 'administrator') }
  let(:branch_role) { create(:system_role, :branch) }

  describe '#index?' do
    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it { expect(policy.index?).to be(true) }
    end

    context 'when the user has an active branch role' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { expect(policy.index?).to be(true) }
    end

    context 'when the user has no branch access' do
      let(:user) { create(:user) }

      it { expect(policy.index?).to be(false) }
    end
  end

  describe '#show?' do
    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it { expect(policy.show?).to be(true) }
    end

    context 'when the user is assigned to the branch' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { expect(policy.show?).to be(true) }
    end

    context 'when the user is assigned to another branch' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch: other_branch) }

      it { expect(policy.show?).to be(false) }
    end
  end

  describe '#create?' do
    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it { expect(policy.create?).to be(true) }
    end

    context 'when the user only has branch access' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { expect(policy.create?).to be(false) }
    end
  end

  describe '#update?' do
    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it { expect(policy.update?).to be(true) }
    end

    context 'when the user only has branch access' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { expect(policy.update?).to be(false) }
    end
  end

  describe '#destroy?' do
    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it { expect(policy.destroy?).to be(true) }
    end

    context 'when the user only has branch access' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { expect(policy.destroy?).to be(false) }
    end
  end

  describe 'Scope' do
    let(:scope) { described_class::Scope.new(user, Branch).resolve }

    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it 'returns all active branches' do
        deleted_branch = create(:branch, deleted_at: Time.current)

        expect(scope).to contain_exactly(branch, other_branch)
        expect(scope).not_to include(deleted_branch)
      end
    end

    context 'when the user has branch access' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it 'returns only assigned active branches' do
        deleted_branch = create(:branch, deleted_at: Time.current)
        create(:user_role, user:, system_role: branch_role, branch: deleted_branch)

        expect(scope).to contain_exactly(branch)
      end
    end
  end
end

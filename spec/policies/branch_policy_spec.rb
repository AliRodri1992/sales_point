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

      it { is_expected.to permit_action(:index) }
    end

    context 'when the user has an active branch role' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { is_expected.to permit_action(:index) }
    end

    context 'when the user has no branch access' do
      let(:user) { create(:user) }

      it { is_expected.not_to permit_action(:index) }
    end
  end

  describe '#show?' do
    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it { is_expected.to permit_action(:show) }
    end

    context 'when the user is assigned to the branch' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { is_expected.to permit_action(:show) }
    end

    context 'when the user is assigned to another branch' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch: other_branch) }

      it { is_expected.not_to permit_action(:show) }
    end
  end

  describe '#create?' do
    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it { is_expected.to permit_action(:create) }
    end

    context 'when the user only has branch access' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { is_expected.not_to permit_action(:create) }
    end
  end

  describe '#update?' do
    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it { is_expected.to permit_action(:update) }
    end

    context 'when the user only has branch access' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { is_expected.not_to permit_action(:update) }
    end
  end

  describe '#destroy?' do
    context 'when the user is a system administrator' do
      let(:user) { create(:user, system_roles: [system_admin_role]) }

      it { is_expected.to permit_action(:destroy) }
    end

    context 'when the user only has branch access' do
      let(:user) { create(:user) }

      before { create(:user_role, user:, system_role: branch_role, branch:) }

      it { is_expected.not_to permit_action(:destroy) }
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

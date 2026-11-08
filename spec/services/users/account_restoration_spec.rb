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
    create(:organization_membership, user:, organization:, account_status: :deleted)
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

  def restore(reason: 'Authorized review', actor: administrator)
    described_class.new(user:, actor:, organization:, reason:).call!
  end

  it 'revokes assignments to inactive roles before restoring a global account' do
    role = create(:system_role, :system, code: 'cashier')
    assignment = user.user_roles.create!(system_role: role)
    role.status = :inactive
    role.save!(context: :status_transition)

    restore

    expect(assignment.reload.deleted_at).to be_present
    role.status = :active
    role.save!(context: :status_transition)
    expect(user.reload.user_roles.active).to be_empty
    expect(user.session_revoked_at).to be_present
  end

  it 'revokes local access in archived branches without changing another organization' do
    other_organization = create(:organization)
    other_membership = create(:organization_membership, user:, organization: other_organization)
    user.update!(status: :active, deleted_at: nil)
    local_branch = create(:branch, organization:)
    other_branch = create(:branch, organization: other_organization)
    role = create(:system_role, :branch)
    local_assignment = create(:user_role, user:, system_role: role, branch: local_branch)
    other_assignment = create(:user_role, user:, system_role: role, branch: other_branch)
    # Historical data can contain archived branches that predate current lifecycle protections.
    # Historical data predates protections against deleting assigned branches.
    # rubocop:disable Rails/SkipsModelValidations
    local_branch.update_columns(deleted_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    role.status = :inactive
    role.save!(context: :status_transition)

    restore

    expect(local_assignment.reload.deleted_at).to be_present
    expect(other_assignment.reload.deleted_at).to be_nil
    expect(other_membership.reload).to be_account_active
    expect(user.reload).to be_active
    expect(user.organization_memberships.find_by!(organization:)).to be_account_active
  end

  it 'restores a shared inactive account as pending in the selected organization' do
    create(:organization_membership, user:)

    restore

    expect(user.organization_memberships.find_by!(organization:)).to be_account_pending
    expect(user.reload).to be_deleted
  end

  ['', 'x' * 1001].each do |reason|
    it "rejects a restoration reason with #{reason.length} characters" do
      expect { restore(reason:) }.to raise_error(ArgumentError, 'Reason required')
      expect(user.reload).to be_deleted
    end
  end

  it 'rejects a non-root actor' do
    administrator.user_roles.destroy_all
    expect { restore }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'rejects an inactive actor' do
    administrator.update!(status: :suspended)
    expect { restore }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'requires the explicit restoration permission' do
    super_role.system_role_permissions.destroy_all
    expect { restore }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'rejects an inactive organization' do
    organization.update!(status: :inactive)
    expect { restore }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'rejects an actor without accessible membership' do
    administrator.organization_memberships.find_by!(organization:).update!(status: :inactive)
    expect { restore }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'rejects an account that is not archived locally' do
    user.organization_memberships.find_by!(organization:).update!(account_status: :suspended)
    expect { restore }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'does not allow self restoration' do
    administrator.organization_memberships.find_by!(organization:).update!(account_status: :deleted)
    expect do
      described_class.new(user: administrator, actor: administrator, organization:, reason: 'Review').call!
    end.to raise_error(Pundit::NotAuthorizedError)
  end
end

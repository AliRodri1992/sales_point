# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::StatusTransition do
  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:actor) { create(:user, system_roles: [role]) }
  let(:user) { create(:user, user_type: :customer) }
  let!(:membership) { create(:organization_membership, user:, organization:) }

  before do
    create(:organization_membership, user: actor, organization:)
    %w[suspend block unblock reactivate destroy].each do |action|
      permission = Permission.find_or_create_by!(code: "users.#{action}") do |record|
        record.name = "User #{action}"
        record.module_name = 'Usuarios'
        record.status = :active
      end
      SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    end
  end

  def transition(target: 'suspended', reason: 'Administrative review', details: {})
    described_class.new(user:, actor:, organization:, target:, reason:, details:).call!
  end

  it 'schedules a future review without changing unrelated memberships' do
    review_at = 2.days.from_now.change(usec: 0)
    transition(details: { review_at: review_at.iso8601 })
    expect(membership.reload).to be_account_suspended
    expect(membership.status_review_at).to eq(review_at)
  end

  ['not a date', '2000-01-01'].each do |date|
    it "rejects the invalid suspension review date #{date}" do
      expect { transition(details: { review_at: date }) }.to raise_error(ArgumentError)
      expect(membership.reload).to be_account_active
      expect(UserStatusEvent.where(user:)).to be_empty
    end
  end

  it 'requires an active actor with the requested granular permission' do
    actor.update!(status: :suspended)
    expect { transition }.to raise_error(Pundit::NotAuthorizedError)
    actor.update!(status: :active)
    role.system_role_permissions.joins(:permission).where(permissions: { code: 'users.suspend' }).destroy_all
    expect { transition }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'rejects permission inherited only from another tenant in a direct service call' do
    foreign = create(:organization)
    foreign_branch = create(:branch, organization: foreign, operational_state: 'active')
    branch_role = create(:system_role, :branch)
    actor.user_roles.destroy_all
    create(:user_role, user: actor, branch: foreign_branch, system_role: branch_role)
    %w[users.access users.suspend].each do |code|
      permission = Permission.find_or_create_by!(code:) do |record|
        record.name = code
        record.module_name = 'Usuarios'
        record.status = :active
      end
      SystemRolePermission.find_or_create_by!(system_role: branch_role, permission:)
    end

    expect { transition }.to raise_error(Pundit::NotAuthorizedError)
    expect(membership.reload).to be_account_active
  end

  it 'does not allow an administrator to suspend a peer administrator' do
    create(:user_role, user:, system_role: role)
    expect { transition }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'allows root administrators to suspend ordinary administrators' do
    create(:user_role, user:, system_role: role)
    root = create(:system_role, :system, code: 'super_admin')
    create(:user_role, user: actor, system_role: root)
    transition
    expect(membership.reload).to be_account_suspended
  end

  it 'protects root administrator accounts from status changes' do
    root = create(:system_role, :system, code: 'super_admin')
    create(:user_role, user:, system_role: root)
    create(:user_role, user: actor, system_role: root)
    expect { transition }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'rejects transitions outside an active organization or actor membership' do
    organization.update!(status: :inactive)
    expect { transition }.to raise_error(Pundit::NotAuthorizedError)
    organization.update!(status: :active)
    actor.organization_memberships.find_by!(organization:).update!(status: :inactive)
    expect { transition }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'does not permit a forged transition or an oversized reason' do
    expect { transition(target: 'pending') }.to raise_error(ArgumentError, 'Transition not permitted')
    expect { transition(reason: 'x' * 1001) }.to raise_error(ArgumentError, 'Reason required')
    expect(membership.reload).to be_account_active
  end

  it 'returns blocked accounts only to their previous state after resolving the incident' do
    user.update!(status: :pending)
    membership.update!(account_status: :pending)
    transition(target: 'blocked')
    expect(described_class.allowed_targets(user)).to contain_exactly('pending', 'deleted')
    expect do
      transition(target: 'active', details: { resolution: 'Verified' })
    end.to raise_error(ArgumentError, 'Transition not permitted')
    transition(target: 'pending', details: { resolution: 'Identity verified' })
    expect(membership.reload).to be_account_pending
    expect(UserSecurityIncident.find_by!(user:).resolution).to eq('Identity verified')
  end

  it 'reconstructs an audited incident when a historical block has no incident' do
    transition(target: 'blocked')
    UserSecurityIncident.where(user:).delete_all

    expect do
      transition(target: 'active', details: { resolution: 'Reviewed' })
    end.to change(UserSecurityIncident, :count).by(1)

    expect(membership.reload).to be_account_active
    expect(UserSecurityIncident.last.resolution).to eq('Reviewed')
    expect(UserSecurityIncident.last.resolved_at).to be_present
  end

  it 'archives an account and revokes outstanding invitations' do
    user.update!(status: :pending)
    membership.update!(account_status: :pending)
    invitation = UserInvitation.issue!(user:, organization:)
    transition(target: 'deleted')
    expect(user.reload).to be_deleted
    expect(user.deleted_at).to be_present
    expect(invitation.reload.revoked_at).to be_present
  end

  it 'preserves the transition and audit if notification delivery cannot be queued' do
    allow(UserStatusMailer).to receive(:changed).and_raise(IOError, 'Queue unavailable')
    expect { transition }.not_to raise_error
    expect(membership.reload).to be_account_suspended
    expect(UserStatusEvent.where(user:, to_status: 'suspended')).to exist
  end

  it 'retains session revocation even if the socket server is unavailable' do
    allow(ActionCable.server).to receive(:remote_connections).and_raise(IOError, 'Socket unavailable')
    expect { transition }.not_to raise_error
    expect(user.reload.session_revoked_at).to be_present
  end

  it 'returns no transitions for archived or unknown organization accounts' do
    membership.update!(account_status: :deleted)
    expect(described_class.allowed_targets(user, organization:)).to be_empty
    expect(described_class.allowed_targets(user, organization: create(:organization))).to be_empty
  end
end

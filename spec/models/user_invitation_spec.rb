# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserInvitation, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, status: :pending, user_type: :customer) }

  before { create(:organization_membership, user:, organization:, account_status: :pending) }

  it 'issues a one-use invitation and activates a pending account' do
    invitation = described_class.issue!(user:, organization:)
    expect(invitation.token_digest).not_to eq(invitation.raw_token)
    expect(invitation).to be_usable
    expect(invitation.accept!(token: invitation.raw_token, password: 'newpassword123',
                              password_confirmation: 'newpassword123')).to be(true)
    expect(user.reload).to be_active
    expect(invitation.reload.accepted_at).to be_present
    expect(invitation.accept!(token: invitation.raw_token, password: 'newpassword456',
                              password_confirmation: 'newpassword456')).to be(false)
  end

  it 'revokes older invitations on resend' do
    previous = described_class.issue!(user:, organization:)
    current = described_class.issue!(user:, organization:)
    expect(previous.reload).not_to be_usable
    expect(current).to be_usable
  end

  it 'does not revoke an invitation issued for another organization' do
    secondary = create(:organization)
    create(:organization_membership, user:, organization: secondary, account_status: :pending)
    foreign = described_class.issue!(user:, organization: secondary)

    local = described_class.issue!(user:, organization:)

    expect(foreign.reload.revoked_at).to be_nil
    expect(local).to be_usable
    expect(foreign).to be_usable
  end

  it 'rechecks local membership under the account lock before issuing a token' do
    allow(user).to receive(:with_lock) do |&block|
      user.organization_memberships.find_by!(organization:).update!(account_status: :suspended)
      block.call
    end

    expect { described_class.issue!(user:, organization:) }.to raise_error(ArgumentError, 'Membership required')
    expect(described_class.where(user:, organization:)).to be_empty
  end

  it 'rejects activation after a security block without changing the password' do
    invitation = described_class.issue!(user:, organization:)
    user.update!(status: :blocked)
    expect(invitation.accept!(token: invitation.raw_token, password: 'newpassword123',
                              password_confirmation: 'newpassword123')).to be(false)
    expect(user.reload).to be_blocked
    expect(invitation.reload.accepted_at).to be_nil
  end

  it 'does not activate with a short or mismatched password' do
    invitation = described_class.issue!(user:, organization:)
    expect(invitation.accept!(token: invitation.raw_token, password: '12345678',
                              password_confirmation: '12345678')).to be(false)
    expect(invitation.accept!(token: invitation.raw_token, password: 'newpassword123',
                              password_confirmation: 'mismatch123')).to be(false)
    expect(user.reload).to be_pending
  end

  it 'rejects expired and forged links' do
    invitation = described_class.issue!(user:, organization:)
    expect(invitation.accept!(token: 'invalid', password: 'newpassword123',
                              password_confirmation: 'newpassword123')).to be(false)
    invitation.update!(expires_at: 1.minute.ago)
    expect(invitation).not_to be_usable
    expect(user.reload).to be_pending
  end

  it 'blocks activation after the local membership is suspended' do
    invitation = described_class.issue!(user:, organization:)
    user.organization_memberships.find_by!(organization:).update!(account_status: :suspended)
    expect(invitation).not_to be_usable
    expect(invitation.accept!(token: invitation.raw_token, password: 'newpassword123',
                              password_confirmation: 'newpassword123')).to be(false)
    expect(user.reload).to be_pending
  end

  it 'does not issue or accept invitations for an inactive organization' do
    invitation = described_class.issue!(user:, organization:)
    organization.update!(status: :inactive)
    expect(invitation).not_to be_usable
    expect { described_class.issue!(user:, organization:) }.to raise_error(ArgumentError, 'Membership required')
  end

  it 'rejects issuing an invitation for a locally active account' do
    user.organization_memberships.find_by!(organization:).update!(account_status: :active)
    expect { described_class.issue!(user:, organization:) }.to raise_error(ArgumentError, 'Membership required')
  end

  it 'allows an existing active account to receive a pending organization invitation' do
    user.update!(status: :active)
    invitation = described_class.issue!(user:, organization:)
    expect(invitation).to be_usable
    expect(invitation.accept!(token: invitation.raw_token, password: 'password999',
                              password_confirmation: 'password999')).to be(false)
    expect(user.reload).to be_active
  end

  it 'accepts an active account invitation only with a matching authenticated account' do
    user.update!(status: :active)
    invitation = described_class.issue!(user:, organization:)
    stranger = create(:user)
    expect(invitation.accept_existing!(token: invitation.raw_token, signed_in_user: stranger)).to be(false)
    expect(invitation.accept_existing!(token: invitation.raw_token, signed_in_user: user)).to be(true)
    expect(user.organization_memberships.find_by!(organization:)).to be_account_active
    expect(invitation.reload.accepted_at).to be_present
  end

  it 'requires employees to have an applicable role before receiving an invitation' do
    user.update!(user_type: :employee)
    expect { described_class.issue!(user:, organization:) }.to raise_error(ArgumentError, 'Role required')
  end

  it 'does not issue invitations without active organization membership' do
    user.organization_memberships.find_by!(organization:).update!(status: :inactive)
    expect { described_class.issue!(user:, organization:) }.to raise_error(ArgumentError, 'Membership required')
    expect(described_class.where(user:)).to be_empty
  end
end

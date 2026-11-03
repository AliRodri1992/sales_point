# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserInvitation, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, status: :pending) }

  before { create(:organization_membership, user:, organization:) }

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
end

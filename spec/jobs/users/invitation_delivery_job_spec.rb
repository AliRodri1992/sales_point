# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::InvitationDeliveryJob, type: :job do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, status: :pending) }

  before { create(:organization_membership, user:, organization:, account_status: :pending) }

  it 'does not send a revoked invitation' do
    invitation = UserInvitation.issue!(user:, organization:)
    encrypted = Users::InvitationDeliveryToken.encrypt(invitation.raw_token)
    invitation.update!(revoked_at: Time.current)

    expect(UserInvitationMailer).not_to receive(:invite)
    described_class.perform_now(invitation.id, encrypted)
  end

  it 'queues an encrypted token rather than plaintext' do
    invitation = UserInvitation.issue!(user:, organization:)
    encrypted = Users::InvitationDeliveryToken.encrypt(invitation.raw_token)
    expect(encrypted).not_to include(invitation.raw_token)
    expect { described_class.perform_later(invitation.id, encrypted) }.to have_enqueued_job(described_class)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::InvitationDeliveryJob, type: :job do
  include ActiveJob::TestHelper

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
    expect { described_class.perform_later(invitation.id, encrypted) }
      .to have_enqueued_job(described_class).with(invitation.id, encrypted).on_queue('mailers')
  end

  it 'delivers a valid invitation and records its delivery time' do
    invitation = UserInvitation.issue!(user:, organization:)
    encrypted = Users::InvitationDeliveryToken.encrypt(invitation.raw_token)
    expect { described_class.perform_now(invitation.id, encrypted) }
      .to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(invitation.reload.delivery_status).to eq('sent')
    expect(invitation.delivery_attempted_at).to be_present
  end

  it 'ignores invitations removed before the worker starts' do
    expect(UserInvitationMailer).not_to receive(:invite)
    described_class.perform_now(-1, 'unused')
  end

  it 'marks delivery failures and schedules a retry' do
    invitation = UserInvitation.issue!(user:, organization:)
    allow(UserInvitationMailer).to receive(:invite).and_raise(IOError, 'Mail unavailable')
    expect { described_class.perform_now(invitation.id, 'encrypted') }
      .to have_enqueued_job(described_class)
    expect(invitation.reload.delivery_status).to eq('failed')
  end

  it 'stops retrying after the configured attempt limit' do
    invitation = UserInvitation.issue!(user:, organization:)
    expect(UserInvitationMailer).to receive(:invite).exactly(5).times.and_raise(IOError, 'Mail unavailable')
    perform_enqueued_jobs(only: described_class) { described_class.perform_later(invitation.id, 'encrypted') }
    expect(invitation.reload.delivery_status).to eq('failed')
  end
end

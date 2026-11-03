# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::AdminAccountWriter, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, status: :pending, email: 'old-invite@example.com') }

  before { create(:organization_membership, user:, organization:) }

  it 'revokes an outstanding invitation when the email changes' do
    invitation = UserInvitation.issue!(user:, organization:)
    writer = described_class.new(user:, organization:, attributes: { email: 'new-invite@example.com' })
    expect(writer.save).to be(true)
    expect(invitation.reload.revoked_at).to be_present
    expect(user.reload).to be_pending
  end
end

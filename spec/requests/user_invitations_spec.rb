# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User invitation activation', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, status: :pending) }

  before { create(:organization_membership, user:, organization:) }

  it 'renders activation and accepts a valid one-time token' do
    invitation = UserInvitation.issue!(user:, organization:)
    get user_invitation_path(token: invitation.raw_token)
    expect(response).to have_http_status(:ok)
    patch accept_user_invitation_path(token: invitation.raw_token),
          params: { invitation: { password: 'newpassword123', password_confirmation: 'newpassword123' } }
    expect(response).to redirect_to(new_user_session_path)
    expect(user.reload).to be_active
  end

  it 'does not allow an expired invitation' do
    invitation = UserInvitation.issue!(user:, organization:)
    invitation.update!(expires_at: 1.minute.ago)
    get user_invitation_path(token: invitation.raw_token)
    expect(response).to have_http_status(:gone)
  end
end

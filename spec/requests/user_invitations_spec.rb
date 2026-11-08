# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User invitation activation', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, status: :pending) }

  before { create(:organization_membership, user:, organization:, account_status: :pending) }

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

  it 'rejects missing and unknown tokens on both activation endpoints' do
    [nil, 'unknown-token'].each do |token|
      get user_invitation_path(token:)
      expect(response).to have_http_status(:gone)
      patch accept_user_invitation_path(token:), params: { invitation: { password: 'password123' } }
      expect(response).to have_http_status(:gone)
    end
    expect(user.reload).to be_pending
  end

  it 'shows model validation below password fields without native required attributes' do
    invitation = UserInvitation.issue!(user:, organization:)
    get user_invitation_path(token: invitation.raw_token)
    document = Nokogiri::HTML(response.body)
    expect(document.css('form[novalidate]')).not_to be_empty
    expect(document.css('input[required], input[minlength]')).to be_empty

    patch accept_user_invitation_path(token: invitation.raw_token), params: {
      invitation: { password: 'short', password_confirmation: 'different' }
    }
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#user_password_error')).to be_present
    expect(document.at_css('#invitation_password[aria-describedby="user_password_error"]')).to be_present
  end

  it 'keeps a usable invitation pending after password validation fails' do
    invitation = UserInvitation.issue!(user:, organization:)
    patch accept_user_invitation_path(token: invitation.raw_token), params: {
      invitation: { password: 'short', password_confirmation: 'different' }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload).to be_pending
    expect(invitation.reload).to be_usable
  end
end

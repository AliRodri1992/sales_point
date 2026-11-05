# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User management without an organization', type: :request do
  let(:actor) { create(:user) }
  let(:user) { create(:user, status: :pending) }

  before do
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'super_admin'))
    sign_in actor
  end

  it 'denies invitation delivery before accessing any account' do
    expect { post admin_user_invitation_path(user) }.not_to change(UserInvitation, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it 'denies restoration access without a selected organization' do
    get admin_user_restorations_path
    expect(response).to have_http_status(:forbidden)
    post admin_user_restoration_path(user), params: { reason: 'Review' }
    expect(response).to have_http_status(:forbidden)
    expect(user.reload).to be_pending
  end

  it 'denies status management without a selected organization' do
    get edit_admin_user_status_path(user), params: { transition: 'suspended' }
    expect(response).to have_http_status(:forbidden)
    patch admin_user_status_path(user), params: { transition: 'suspended', reason: 'Review' }
    expect(response).to have_http_status(:forbidden)
    expect(user.reload).to be_pending
  end

  it 'does not create accounts or expose user details without an organization' do
    expect do
      post admin_users_path, params: { user: { email: 'new@example.org' } }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:forbidden)
    get admin_user_path(user)
    expect(response).to have_http_status(:forbidden)
  end
end

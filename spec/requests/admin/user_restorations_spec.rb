# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin archived user restoration', type: :request do
  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'super_admin') }
  let(:administrator) { create(:user, system_roles: [role]) }
  let(:user) { create(:user, status: :deleted, deleted_at: Time.current) }

  before do
    permission = Permission.find_or_create_by!(code: 'users.restore') do |record|
      record.name = 'Restore users'
      record.module_name = 'Usuarios'
      record.status = :active
    end
    SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    create(:organization_membership, user: administrator, organization:)
    create(:organization_membership, user:, organization:, account_status: :deleted)
    sign_in administrator
  end

  it 'lists only archived accounts belonging to the current organization' do
    foreign = create(:user, status: :deleted, deleted_at: Time.current)
    create(:organization_membership, user: foreign, account_status: :deleted)
    get admin_user_restorations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(user.email)
    expect(response.body).not_to include(foreign.email)
  end

  it 'restores the account to pending and records the reason' do
    post admin_user_restoration_path(user), params: { reason: 'Authorized review' }
    expect(response).to redirect_to(admin_user_path(user))
    expect(user.reload).to be_pending
    expect(UserStatusEvent.find_by!(user:, organization:).reason).to eq('Authorized review')
  end

  it 'reports a missing reason without restoring the account' do
    post admin_user_restoration_path(user), params: { reason: '' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css('#users_account_restoration_reason_error')).to be_present
    expect(Nokogiri::HTML(response.body).css('form input[required]')).to be_empty
    expect(user.reload).to be_deleted
  end

  it 'filters archived accounts without exposing other organizations' do
    found = create(:user, status: :deleted, deleted_at: Time.current, email: 'archived-find@example.com')
    create(:organization_membership, user: found, organization:, account_status: :deleted)

    get admin_user_restorations_path, params: { q: 'archived-find' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(found.email)
    expect(response.body).not_to include(user.email)
  end

  it 'paginates more than twenty archived user memberships' do
    20.times do |index|
      email = "archive-page-#{index}@example.com"
      archived = create(:user, status: :deleted, deleted_at: Time.current, email:)
      create(:organization_membership, user: archived, organization:, account_status: :deleted)
    end

    get admin_user_restorations_path, params: { page: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(user.email)
    expect(Nokogiri::HTML(response.body).at_css('nav[aria-label]')).to be_present
  end

  it 'rejects an archived account from another organization' do
    user.organization_memberships.find_by!(organization:).update!(organization: create(:organization))
    post admin_user_restoration_path(user), params: { reason: 'Review' }
    expect(response).to have_http_status(:not_found)
  end

  it 'requires explicit restoration permission' do
    role.system_role_permissions.destroy_all
    get admin_user_restorations_path
    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects an ordinary administrator even with restoration permission' do
    role.update!(code: 'administrator')
    get admin_user_restorations_path
    expect(response).to have_http_status(:forbidden)
  end
end

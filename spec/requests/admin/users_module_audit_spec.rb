# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Audited users access boundaries', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, user: administrator, organization:)
    sign_in administrator
  end

  def add_member(user, organization: self.organization)
    create(:organization_membership, user:, organization:)
    user
  end

  it 'prevents the last administrator from removing their own administrative role' do
    patch admin_user_path(administrator), params: { user: { system_role_ids: [''] } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css('#user_system_role_ids_error')).to be_present
    expect(administrator.reload).to be_admin
  end

  it 'rejects global role changes for an account shared by two organizations' do
    target = add_member(create(:user, email: 'shared-global@example.com'))
    add_member(target, organization: create(:organization))
    role = create(:system_role, :system, code: 'shared_global_role')

    patch admin_user_path(target), params: { user: { system_role_ids: ['', role.id.to_s] } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css('#user_system_role_ids_error')).to be_present
    expect(target.user_roles.active).to be_empty
  end

  it 'rejects a global identity change for shared accounts' do
    target = add_member(create(:user, email: 'shared-identity@example.com'))
    add_member(target, organization: create(:organization))

    patch admin_user_path(target), params: { user: { username: 'Other Organization Edit' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css('#user_username_error')).to be_present
    expect(target.reload.username).not_to eq('Other Organization Edit')
  end

  it 'marks the session revoked when changing an active role' do
    target = add_member(create(:user, email: 'access-change@example.com'))
    role = create(:system_role, :system, code: 'access_change_role')

    patch admin_user_path(target), params: { user: { system_role_ids: ['', role.id.to_s] } }

    expect(response).to redirect_to(admin_user_path(target))
    expect(target.reload.session_revoked_at).to be_present
    expect(target.user_roles.active.exists?(system_role: role)).to be(true)
  end

  it 'reissues the invitation when email and roles change together' do
    target = add_member(create(:user, status: :pending, email: 'combined-original@example.com'))
    target.organization_memberships.find_by!(organization:).update!(account_status: :pending)
    role = create(:system_role, :system, code: 'combined_role_change')

    expect do
      patch admin_user_path(target), params: {
        user: { email: 'combined-updated@example.com', system_role_ids: ['', role.id.to_s] }
      }
    end.to change(UserInvitation, :count).by(1)

    expect(response).to redirect_to(admin_user_path(target))
    expect(target.reload.email).to eq('combined-updated@example.com')
    expect(target.session_revoked_at).to be_present
    expect(target.user_roles.active.exists?(system_role: role)).to be(true)
  end

  it 'reissues the invitation when the email of a pending user is changed' do
    target = add_member(create(:user, status: :pending, email: 'original-invite@example.com'))
    target.organization_memberships.find_by!(organization:).update!(account_status: :pending)

    expect do
      patch admin_user_path(target), params: { user: { email: 'revised-invite@example.com' } }
    end.to change(UserInvitation, :count).by(1)

    expect(response).to redirect_to(admin_user_path(target))
    expect(target.reload.email).to eq('revised-invite@example.com')
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin user organization and role boundaries', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:admin_role) { create(:system_role, :system, code: 'administrator') }
  let(:admin) { create(:user, system_roles: [admin_role]) }

  before do
    create(:organization_membership, user: admin, organization:)
    sign_in admin
  end

  def member(user, organization: self.organization)
    create(:organization_membership, user:, organization:)
    user
  end

  it 'does not list or expose users belonging only to another organization' do
    mine = member(create(:user, email: 'mine@example.com'))
    foreign = member(create(:user, email: 'foreign@example.com'), organization: other_organization)

    get admin_users_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(mine.email)
    expect(response.body).not_to include(foreign.email)

    get admin_user_path(foreign)
    expect(response).to have_http_status(:not_found)
    get edit_admin_user_path(foreign)
    expect(response).to have_http_status(:not_found)
    patch admin_user_path(foreign), params: { user: { email: 'changed@example.com' } }
    expect(response).to have_http_status(:not_found)
    delete admin_user_path(foreign)
    expect(response).to have_http_status(:not_found)
    expect(foreign.reload.deleted_at).to be_nil
  end

  it 'does not expose users with revoked organization membership' do
    former = member(create(:user, email: 'former@example.com'))
    former.organization_memberships.first.update!(status: 'inactive')

    get admin_users_path
    expect(response.body).not_to include(former.email)
    get admin_user_path(former)
    expect(response).to have_http_status(:not_found)
  end

  it 'keeps branch-specific roles when system roles are edited' do
    target = member(create(:user))
    branch = create(:branch, organization:)
    branch_role = create(:system_role, :branch, code: 'branch_cashier')
    staff_role = create(:system_role, :system, code: 'staff_role')
    other_role = create(:system_role, :system, code: 'other_role')
    create(:user_role, user: target, system_role: branch_role, branch:)
    create(:user_role, user: target, system_role: staff_role)

    patch admin_user_path(target), params: { user: { system_role_ids: ['', other_role.id.to_s] } }

    expect(response).to redirect_to(admin_user_path(target))
    expect(target.user_roles.active.pluck(:system_role_id)).to contain_exactly(branch_role.id, other_role.id)
    expect(target.user_roles.where(system_role_id: staff_role.id).first.deleted_at).to be_present
  end

  it 'rejects branch roles and inactive global roles sent as forged system roles' do
    target = member(create(:user))
    branch_role = create(:system_role, :branch, code: 'branch_only')
    inactive = create(:system_role, :system, :inactive, code: 'disabled_global')

    [branch_role.id, inactive.id, 'not-an-id'].each do |value|
      patch admin_user_path(target), params: { user: { system_role_ids: ['', value.to_s] } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(target.reload.user_roles.active).to be_empty
    end
  end

  it 'does not overwrite the password when the edit form submits empty password fields' do
    target = member(create(:user, password: 'password123'))

    patch admin_user_path(target), params: {
      user: { username: 'new_name', password: '', password_confirmation: '' }
    }

    expect(response).to redirect_to(admin_user_path(target))
    expect(target.reload).to be_valid_password('password123')
  end

  it 'prevents deleting an account shared by multiple organizations' do
    target = member(create(:user))
    member(target, organization: other_organization)

    delete admin_user_path(target)

    expect(response).to redirect_to(admin_users_path)
    expect(target.reload.deleted_at).to be_nil
    expect(flash[:swal_message]).to eq(I18n.t('admin.users.shared_account_cannot_delete'))
  end

  it 'rejects creating an account when the administrator has no active organization' do
    admin.organization_memberships.update_all(status: 'inactive')

    post admin_users_path, params: { user: { email: 'orphan@example.com', password: 'password123' } }

    expect(response).to have_http_status(:forbidden)
    expect(User.find_by(email: 'orphan@example.com')).to be_nil
  end
end

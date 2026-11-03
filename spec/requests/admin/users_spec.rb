# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Users', type: :request do
  let(:system_admin_role) { create(:system_role, :system, code: 'administrator') }
  let(:admin_user) { create(:user, system_roles: [system_admin_role]) }
  let(:organization) { create(:organization) }

  before do
    create(:organization_membership, user: admin_user, organization:)
    sign_in admin_user
  end

  def add_member(user)
    create(:organization_membership, user:, organization:)
    user
  end

  describe 'GET /admin/users' do
    it 'renders the users index with the list and table headings' do
      add_member(create(:user, email: 'listed@example.com'))

      get admin_users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Usuarios')
      expect(response.body).to include('listed@example.com')
      expect(response.body).to include(I18n.t('admin.users.index.columns.email', locale: :es))
      expect(response.body).to include(I18n.t('admin.users.index.columns.status', locale: :es))
    end
  end

  describe 'GET /admin/users/new' do
    it 'renders the form with default user settings' do
      get new_admin_user_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="user[email]"')
      expect(response.body).to include(Theme::DEFAULT)
      expect(response.body).not_to include('name="user[status]"')
      expect(response.body).not_to include('name="user[password]"')
    end
  end

  describe 'GET /admin/users/:id' do
    it 'renders the user profile' do
      target = add_member(create(:user, email: 'profile@example.com'))

      get admin_user_path(target)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('profile@example.com')
      expect(response.body).to include('Usuarios')
    end

    it 'renders the edit form for an existing user' do
      target = add_member(create(:user, email: 'edit-profile@example.com'))

      get edit_admin_user_path(target)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="user[email]"')
      expect(response.body).to include('edit-profile@example.com')
      expect(response.body).not_to include('name="user[status]"')
    end
  end

  describe 'POST /admin/users' do
    let(:valid_params) do
      {
        user: {
          email: 'created@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          user_type: 'employee',
          status: 'active',
          theme: Theme::DEFAULT
        }
      }
    end

    it 'creates a user and displays the success Swal message' do
      expect { post admin_users_path, params: valid_params }.to change(User, :count).by(1)

      created_user = User.find_by!(email: valid_params.dig(:user, :email))
      expect(created_user).to be_pending
      expect(created_user.user_invitations.count).to eq(1)
      expect(created_user.organization_memberships.active.pluck(:organization_id)).to eq([organization.id])
      expect(response).to redirect_to(admin_users_path)
      follow_redirect!
      expect(response.body).to include(I18n.t('admin.users.created', locale: :es))
      expect(User.exists?(created_user.id)).to be(true)
    end

    it 're-renders the form with validation errors and no required attributes' do
      post admin_users_path,
           params: { user: { email: '', password: 'pw', password_confirmation: 'pw',
                             user_type: 'employee', status: 'active', theme: Theme::DEFAULT } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('rose-500')
      assert_select 'p.mt-1.text-xs.text-rose-600'
      expect(response.body).not_to match(/name="user\[email\]"[^>]*\brequired\b/)
    end
  end

  describe 'PATCH /admin/users/:id' do
    it 'updates a user and sends the success notification message' do
      target = add_member(create(:user, email: 'before-update@example.com'))

      patch admin_user_path(target), params: { user: { email: 'after-update@example.com' } }

      expect(response).to redirect_to(admin_user_path(target))
      expect(target.reload.email).to eq('after-update@example.com')
      expect(flash[:swal_message]).to eq(I18n.t('admin.users.updated', locale: :es))
    end

    it 'does not accept forged administrative status updates' do
      target = add_member(create(:user, status: :active))
      patch admin_user_path(target), params: { user: { status: 'blocked', username: 'safe' } }
      expect(target.reload.status).to eq('active')
      expect(target.username).to eq('safe')
    end

    it 're-renders the edit form when validation fails' do
      target = add_member(create(:user, email: 'valid-user@example.com'))

      patch admin_user_path(target), params: { user: { email: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('rose-500')
      expect(target.reload.email).to eq('valid-user@example.com')
    end
  end

  describe 'Administrative account removal' do
    it 'requires a reason and records a soft deletion' do
      target = add_member(create(:user, email: 'deleted@example.com'))
      patch admin_user_status_path(target), params: { transition: 'deleted', reason: 'Employee departure' }

      expect(response).to redirect_to(admin_users_path)
      expect(User.with_deleted.find(target.id).deleted_at).to be_present
      event = UserStatusEvent.find_by!(user: target, to_status: 'deleted')
      expect(event.reason).to eq('Employee departure')
    end

    it 'rejects legacy DELETE requests without a reason' do
      target = add_member(create(:user, email: 'legacy-delete@example.com'))
      delete admin_user_path(target)
      expect(response).to have_http_status(:method_not_allowed)
      expect(target.reload.deleted_at).to be_nil
    end
  end

  describe 'server-side pagination and sorting boundaries' do
    before do
      16.times do |index|
        add_member(create(:user, email: format('paginate-%02d@example.com', index),
                                 username: format('employee_%02d', index)))
      end
    end

    it 'honors permitted sorting and a small page size for a long user list' do
      get admin_users_path, params: {
        q: 'paginate-', per_page: 5, sort: 'users.username', direction: 'desc'
      }

      rows = Nokogiri::HTML(response.body).css('tbody tr')
      expect(response).to have_http_status(:ok)
      expect(rows.length).to eq(5)
      expect(rows.first.text).to include('employee_15')
    end

    it 'clamps pagination beyond the final page instead of showing an empty list' do
      get admin_users_path, params: { per_page: 5, page: 999 }

      rows = Nokogiri::HTML(response.body).css('tbody tr')
      expect(response).to have_http_status(:ok)
      expect(rows.length).to be_between(1, 5)
    end

    it 'ignores unsupported page sizes and SQL sort tokens' do
      get admin_users_path, params: {
        per_page: 99, sort: 'users.password_digest', direction: 'DESC;DELETE'
      }

      rows = Nokogiri::HTML(response.body).css('tbody tr')
      expect(response).to have_http_status(:ok)
      expect(rows.length).to eq(10)
      expect(rows.first.text).not_to include('password_digest')
    end
  end
end

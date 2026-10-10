# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Users', type: :request do
  let(:system_admin_role) { create(:system_role, :system, code: 'administrator') }
  let(:admin_user) { create(:user, system_roles: [system_admin_role]) }

  before { sign_in admin_user }

  describe 'GET /admin/users' do
    it 'renders the users index with the list and table headings' do
      create(:user, email: 'listed@example.com')

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
    end
  end

  describe 'GET /admin/users/:id' do
    it 'renders the user profile' do
      target = create(:user, email: 'profile@example.com')

      get admin_user_path(target)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('profile@example.com')
      expect(response.body).to include('Usuarios')
    end

    it 'renders the edit form for an existing user' do
      target = create(:user, email: 'edit-profile@example.com')

      get edit_admin_user_path(target)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="user[email]"')
      expect(response.body).to include('edit-profile@example.com')
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
      post admin_users_path, params: valid_params

      expect(response).to redirect_to(admin_users_path)
      follow_redirect!
      expect(response.body).to include(I18n.t('admin.users.created', locale: :es))
      expect(User.find_by(email: 'created@example.com')).to be_present
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
      target = create(:user, email: 'before-update@example.com')

      patch admin_user_path(target), params: { user: { email: 'after-update@example.com' } }

      expect(response).to redirect_to(admin_user_path(target))
      expect(target.reload.email).to eq('after-update@example.com')
      expect(flash[:swal_message]).to eq(I18n.t('admin.users.updated', locale: :es))
    end

    it 're-renders the edit form when validation fails' do
      target = create(:user, email: 'valid-user@example.com')

      patch admin_user_path(target), params: { user: { email: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('rose-500')
      expect(target.reload.email).to eq('valid-user@example.com')
    end
  end

  describe 'DELETE /admin/users/:id' do
    it 'soft-deletes a user and displays the success Swal message' do
      target = create(:user, email: 'deleted@example.com')

      delete admin_user_path(target)

      expect(response).to redirect_to(admin_users_path)
      follow_redirect!
      expect(response.body).to include(I18n.t('admin.users.destroyed', locale: :es))
      expect(User.with_deleted.find_by(email: 'deleted@example.com').deleted_at).to be_present
    end

    it 'prevents an admin from deleting their own account' do
      delete admin_user_path(admin_user)

      expect(response).to redirect_to(admin_users_path)
      follow_redirect!
      expect(response.body).to include(I18n.t('admin.users.cannot_delete_self', locale: :es))
      expect(admin_user.reload.deleted_at).to be_nil
    end
  end
end

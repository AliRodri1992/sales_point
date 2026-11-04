# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Granular catalog authorization', type: :request do
  include SqlQueryRecorder

  let(:organization) { create(:organization) }
  let(:actor) { create(:user, :english) }
  let(:role) { create(:system_role, :system) }

  before do
    create(:organization_membership, user: actor, organization:)
    create(:user_role, user: actor, system_role: role)
    sign_in actor
  end

  after { sign_out actor }

  def grant(*codes)
    codes.each do |code|
      permission = Permission.find_or_create_by!(code:) do |item|
        item.name = code
        item.module_name = code.split('.').first
        item.status = :active
      end
      create(:system_role_permission, system_role: role, permission:)
    end
  end

  { language: 'languages', product: 'products', client: 'customers', category: 'categories' }.each do |model, prefix|
    context prefix do
      let(:record) do
        attributes = model == :product ? { organization: } : {}
        create(model, **attributes)
      end
      let(:collection_path) { public_send("admin_#{model.to_s.pluralize}_path") }
      let(:record_path) { public_send("admin_#{model}_path", record) }
      let(:edit_path) { public_send("edit_admin_#{model}_path", record) }
      let(:new_path) { public_send("new_admin_#{model}_path") }

      it 'does not grant any CRUD operations from the old access permission alone' do
        grant("#{prefix}.access")
        get collection_path
        expect(response).to have_http_status(:forbidden)
        get record_path
        expect(response).to have_http_status(:forbidden)
        post collection_path, params: { model => { name: 'Forged create' } }
        expect(response).to have_http_status(:forbidden)
        patch record_path, params: { model => { name: 'Forged update' } }
        expect(response).to have_http_status(:forbidden)
        delete record_path
        expect(response).to have_http_status(:forbidden)
        expect(record.reload.deleted_at).to be_nil
      end

      it 'lists without exposing edit, create or delete actions' do
        record
        grant("#{prefix}.access", "#{prefix}.index")
        get collection_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("href=\"#{new_path}\"", "href=\"#{edit_path}\"")
        get record_path
        expect(response).to have_http_status(:forbidden)
      end

      it 'creates without list access and returns to an authorized screen' do
        grant("#{prefix}.access", "#{prefix}.create")
        attributes = attributes_for(model)
        post collection_path, params: { model => attributes }
        expect(response).to have_http_status(:see_other)
        expect(model.to_s.classify.constantize.find_by(code: attributes[:code])).to be_present
        follow_redirect!
        expect(response).to have_http_status(:ok)
      end

      it 'shows details without allowing an update' do
        grant("#{prefix}.access", "#{prefix}.show")
        get record_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("href=\"#{edit_path}\"")
        get edit_path
        expect(response).to have_http_status(:forbidden)
      end

      it 'updates only with update permission' do
        grant("#{prefix}.access", "#{prefix}.update")
        get edit_path
        expect(response).to have_http_status(:ok)
        patch record_path, params: { model => { name: 'Permitted update' } }
        expect(response).to have_http_status(:redirect)
        expect(record.reload.name).to eq('Permitted update')
        follow_redirect!
        expect(response).to have_http_status(:ok)
        delete record_path
        expect(response).to have_http_status(:forbidden)
      end

      it 'deletes only with destroy permission' do
        grant("#{prefix}.access", "#{prefix}.destroy")
        delete record_path
        expect(response).to have_http_status(:redirect)
        expect(record.class.with_deleted.find(record.id).deleted_at).to be_present
      end
    end
  end

  context 'delegated user management' do
    let(:target) do
      create(:user).tap { |user| create(:organization_membership, user:, organization:) }
    end

    it 'requires an organization even when the account has user permissions' do
      grant('users.access', 'users.index')
      unaffiliated = create(:user)
      create(:user_role, user: unaffiliated, system_role: role)
      sign_in unaffiliated
      get admin_users_path
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows a list-only user to list this organization without edit controls' do
      grant('users.access', 'users.index')
      target
      get admin_users_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("href=\"#{edit_admin_user_path(target)}\"")
      sign_in actor.reload
      get admin_user_path(target)
      expect(response).to have_http_status(:forbidden)
    end

    it 'does not repeat permission queries for every user row' do
      grant('users.access', 'users.index', 'users.show', 'users.update', 'users.destroy')
      target
      small = recorded_sql_queries { get admin_users_path(per_page: 10) }.grep(/INNER JOIN "permissions"/).size
      8.times { create(:organization_membership, user: create(:user), organization:) }
      large = recorded_sql_queries { get admin_users_path(per_page: 10) }.grep(/INNER JOIN "permissions"/).size
      expect(response).to have_http_status(:ok)
      expect(large).to be <= small + 2
    end

    it 'allows identity edits without permitting role assignment or administrator edits' do
      grant('users.access', 'users.update')
      patch admin_user_path(target), params: { user: { username: 'Updated identity' } }
      expect(response).to have_http_status(:redirect)
      expect(target.reload.username).to eq('Updated identity')
      patch admin_user_path(target), params: { user: { system_role_ids: [role.id] } }
      expect(response).to have_http_status(:forbidden)
      expect(target.user_roles).to be_empty
      create(:user_role, user: target, system_role: create(:system_role, :system, code: 'administrator'))
      patch admin_user_path(target), params: { user: { username: 'Forged admin edit' } }
      expect(response).to have_http_status(:forbidden)
    end

    it 'requires invitation permission as well as create permission' do
      grant('users.access', 'users.create')
      get new_admin_user_path
      expect(response).to have_http_status(:forbidden)
      grant('users.invite')
      get new_admin_user_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="user[system_role_ids][]"')
    end

    it 'creates a pending account but cannot assign administrator access' do
      grant('users.access', 'users.create', 'users.invite')
      administrator = create(:system_role, :system, code: 'administrator')
      expect do
        post admin_users_path, params: { user: { email: 'forged-role@example.com',
                                                 system_role_ids: [administrator.id] } }
      end.not_to change(User, :count)
      expect(response).to have_http_status(:forbidden)
      sign_in actor.reload
      post admin_users_path, params: { user: { email: 'delegated-created@example.com', username: 'New colleague',
                                               user_type: 'employee', theme: Theme::DEFAULT } }
      expect(response).to have_http_status(:see_other)
      created = User.find_by!(email: 'delegated-created@example.com')
      expect(created).to be_pending
      expect(created.user_roles).to be_empty
      expect(created.organization_memberships.exists?(organization:)).to be(true)
    end

    it 'uses the audited deletion flow and requires a reason' do
      grant('users.access', 'users.destroy')
      patch admin_user_status_path(target), params: { transition: 'deleted', reason: '' }
      expect(target.reload).to be_active
      patch admin_user_status_path(target), params: { transition: 'deleted', reason: 'Account no longer needed' }
      expect(target.class.with_deleted.find(target.id).status).to eq('deleted')
      expect(UserStatusEvent.where(user: target).last.reason).to eq('Account no longer needed')
    end

    it 'does not expose users in another organization' do
      grant('users.access', 'users.index', 'users.show', 'users.update')
      other = create(:user)
      create(:organization_membership, user: other, organization: create(:organization))
      get admin_user_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end
end

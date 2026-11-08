# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Users', type: :request do
  let(:system_admin_role) { create(:system_role, :system, code: 'administrator') }
  let(:employee_role) { create(:system_role, :system, code: 'warehouse_operator') }
  let(:admin_user) { create(:user, system_roles: [system_admin_role]) }
  let(:organization) { create(:organization) }

  before do
    permission = Permission.find_or_create_by!(code: 'users.destroy') do |item|
      item.name = 'Remove user'
      item.module_name = 'Usuarios'
      item.status = :active
    end
    SystemRolePermission.find_or_create_by!(system_role: system_admin_role, permission:)
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

  describe 'Active users filter chips' do
    it 'shows a removable chip for every applied filter and preserves the other criteria' do
      get admin_users_path, params: {
        q: 'staff', user_type: 'employee', status: 'pending',
        role: system_admin_role.id, sort: 'users.username', direction: 'desc', per_page: 5, page: 2
      }

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      section = document.at_css('#users-active-filters')
      expect(section).to be_present
      chips = section.css('a[data-user-filter]')
      expect(chips.pluck('data-user-filter')).to eq(%w[q user_type status role])
      expect(section.text).to include(
        'staff',
        I18n.t('admin.users.user_types.employee'),
        I18n.t('admin.users.statuses.pending')
      )

      remove_status = chips.find { |chip| chip['data-user-filter'] == 'status' }
      query = Rack::Utils.parse_query(URI.parse(remove_status['href']).query)
      expect(query).to include(
        'q' => 'staff', 'user_type' => 'employee', 'role' => system_admin_role.id.to_s,
        'sort' => 'users.username', 'direction' => 'desc', 'per_page' => '5'
      )
      expect(query).not_to have_key('status')
      expect(query).not_to have_key('page')
      expect(remove_status['data-turbo-frame']).to eq('_top')
    end

    it 'hides chips without filters and offers removal of all filters' do
      get admin_users_path

      expect(Nokogiri::HTML(response.body).at_css('#users-active-filters')).to be_nil

      get admin_users_path, params: { q: 'staff', status: 'active', per_page: 10 }

      section = Nokogiri::HTML(response.body).at_css('#users-active-filters')
      expect(section).to be_present
      clear = section.css('a').find { |link| link.text.include?(I18n.t('admin.users.ui.clear_active_filters')) }
      expect(clear).to be_present
      expect(Rack::Utils.parse_query(URI.parse(clear['href']).query)).to eq('per_page' => '10')
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
      expect(response.body).to include('data-user-access-target="submitButton"')
      expect(response.body).to include('data-empty-label=')
      expect(response.body).to include('maxlength="254"')
      theme = Nokogiri::HTML(response.body).at_css('select#user_theme')
      expect(theme).to be_present
      expect(theme.css('option[value=""]')).to be_empty
      expect(theme.at_css("option[value='#{Theme::DEFAULT}'][selected]")).to be_present
      expect(response.body).to include('id="users-create-deltin"')
      expect(response.body).to include('id="users-review-title"')
      expect(response.body).to include('data-user-access-target="reviewEmail"')
      expect(response.body).to include('data-user-access-target="themeSwatch"')
      expect(response.body).not_to include('xl:sticky xl:top-24')
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
      expect(Nokogiri::HTML(response.body).css('select#user_theme option[value=""]')).to be_empty
      expect(response.body).not_to include('id="users-create-deltin"')
      expect(response.body).to include('xl:sticky xl:top-24')
      expect(response.body).not_to include('name="user[status]"')
    end
  end

  it 'forbids creation when the operator only has a revoked administrator role' do
    admin_user.user_roles.where(system_role: system_admin_role).find_each do |assignment|
      assignment.update!(deleted_at: Time.current)
    end

    get new_admin_user_path
    expect(response).to have_http_status(:forbidden)

    post admin_users_path, params: { user: { email: 'blocked@example.com', user_type: 'employee' } }
    expect(response).to have_http_status(:forbidden)
    expect(User.exists?(email: 'blocked@example.com')).to be(false)
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
          theme: Theme::DEFAULT,
          system_role_ids: ['', employee_role.id.to_s]
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


    it 'requires an employee to have at least one global or branch role' do
      post admin_users_path, params: {
        user: { email: 'without-roles@example.com', user_type: 'employee',
                theme: Theme::DEFAULT, system_role_ids: [''], branch_role_assignments: [''] }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.exists?(email: 'without-roles@example.com')).to be(false)
      document = Nokogiri::HTML(response.body)
      message = document.at_css('#user_system_role_ids_error')
      expect(message).to be_present
      expect(message.text).to start_with(I18n.t('admin.users.ui.roles_and_permissions'))
      expect(message.text).to include(I18n.t('activerecord.errors.models.user.attributes.system_role_ids.at_least_one'))
      expect(document.at_css('#users-access-title [data-required-indicator]')).to be_present
    end

    it 'accepts a branch-only assignment as the employee minimum role' do
      branch = create(:branch, organization:)
      local_role = create(:system_role, :branch, code: 'inventory_branch')

      post admin_users_path, params: {
        user: { email: 'branch-only@example.com', user_type: 'employee', theme: Theme::DEFAULT,
                system_role_ids: [''], branch_role_assignments: ['', "#{branch.id}:#{local_role.id}"] }
      }

      expect(response).to redirect_to(admin_users_path)
      created = User.find_by!(email: 'branch-only@example.com')
      expect(created.user_roles.active.exists?(branch:, system_role: local_role)).to be(true)
    end

    it 'allows customer and supplier accounts without role assignments' do
      %w[customer supplier].each do |kind|
        post admin_users_path, params: {
          user: { email: "account-#{kind}@example.com", user_type: kind, theme: Theme::DEFAULT,
                  system_role_ids: [''], branch_role_assignments: [''] }
        }
        expect(response).to redirect_to(admin_users_path)
        created = User.find_by!(email: "account-#{kind}@example.com")
        expect(created.user_roles.active).to be_empty
      end
    end

    it 'rejects forged branch roles without creating a partially configured account' do
      foreign = create(:organization)
      branch = create(:branch, organization: foreign)
      role = create(:system_role, :branch, code: 'foreign_branch')

      post admin_users_path, params: {
        user: { email: 'forged@example.com', user_type: 'employee', theme: Theme::DEFAULT,
                system_role_ids: [''], branch_role_assignments: ["#{branch.id}:#{role.id}"] }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.exists?(email: 'forged@example.com')).to be(false)
      expect(Nokogiri::HTML(response.body).at_css('#user_branch_role_assignments_error')).to be_present
    end

    it 'normalizes account identity and uses a selectable language by default' do
      post admin_users_path, params: {
        user: { email: '  MIXED@Example.com  ', username: '  Store Team  ', user_type: 'employee',
                theme: Theme::DEFAULT, system_role_ids: ['', employee_role.id.to_s] }
      }

      expect(response).to redirect_to(admin_users_path)
      created = User.find_by!(email: 'mixed@example.com')
      expect(created.username).to eq('Store Team')
      expect(created.language).to be_present
      expect(created.language).to be_in(Language.selectable)
    end

    it 'rejects inactive languages from crafted requests' do
      language = create(:language, :english, status: :inactive)
      post admin_users_path, params: {
        user: { email: 'inactive-language@example.com', user_type: 'employee',
                theme: Theme::DEFAULT, language_id: language.id,
                system_role_ids: ['', employee_role.id.to_s] }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.exists?(email: 'inactive-language@example.com')).to be(false)
      expect(Nokogiri::HTML(response.body).at_css('#user_language_id_error')).to be_present
    end

    it 'validates field lengths on the server, regardless of HTML limits' do
      post admin_users_path, params: {
        user: { email: "#{'a' * 250}@example.com", username: 'U' * 101, user_type: 'employee',
                theme: Theme::DEFAULT, system_role_ids: ['', employee_role.id.to_s] }
      }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('#user_email_error')).to be_present
      expect(document.at_css('#user_username_error')).to be_present
    end

    it 'places all model validation messages beneath the correct field' do
      post admin_users_path, params: {
        user: { email: 'not-an-email', user_type: '', theme: 'invalid-theme' }
      }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('#user_email_error').text).to start_with(
        I18n.t('admin.users.form.fields.email')
      )
      expect(document.at_css('#user_user_type_error').text).to start_with(
        I18n.t('admin.users.form.fields.user_type')
      )
      expect(document.at_css('#user_theme_error').text).to start_with(
        I18n.t('admin.users.form.fields.theme')
      )
    end

    it 'shows red mandatory indicators only for required model attributes without a global error list' do
      get new_admin_user_path

      document = Nokogiri::HTML(response.body)
      form = document.at_css('form[data-controller="user-access"]')
      expect(form).to be_present
      %w[email user_type theme].each do |attribute|
        label = form.at_css("label[for='user_#{attribute}']")
        expect(label.at_css('span[data-required-indicator].text-rose-600').text).to eq('*')
        expect(label.at_css('.sr-only').text).to include(I18n.t('admin.users.ui.required_field'))
      end
      expect(form.at_css('label[for="user_username"] [data-required-indicator]')).to be_nil
      expect(form.at_css('label[for="user_language_id"] [data-required-indicator]')).to be_nil
      expect(form.css('span[data-required-indicator]').length).to eq(4)
      expect(form.css('[required]')).to be_empty
      expect(form.at_css('.catalog-error')).to be_nil
    end

    it 'keeps field errors beneath each control without repeating the validation summary' do
      post admin_users_path, params: {
        user: { email: 'incorrect-email', user_type: '', theme: 'not-a-theme' }
      }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('.catalog-error')).to be_nil
      expect(document.text).not_to include(I18n.t('admin.catalog_design.fix_errors'))
      %w[email user_type theme].each do |attribute|
        field = document.at_css("#user_#{attribute}")
        message = document.at_css("#user_#{attribute}_error")
        expect(field).to be_present
        expect(message).to be_present
        expect(message.parent).to eq(field.parent) if attribute == 'email'
      end
    end

    it 'does not apply browser required checks to any user form field' do
      get new_admin_user_path

      document = Nokogiri::HTML(response.body)
      form = document.at_css('form[data-controller="user-access"]')
      expect(form).to be_present
      expect(form['novalidate']).not_to be_nil
      expect(form.css('input[required], select[required], textarea[required]')).to be_empty
      expect(form.css('[data-validation-field], [data-user-access-target="emailError"]')).to be_empty
      expect(form.css('[data-user-access-target="userTypeError"]')).to be_empty

      target = add_member(create(:user, email: 'edit-without-required@example.com'))
      get edit_admin_user_path(target)
      edit_form = Nokogiri::HTML(response.body).at_css('form[data-controller="user-access"]')
      expect(edit_form.css('input[required], select[required], textarea[required]')).to be_empty
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

  describe 'Protected administrative roles' do
    it 'prevents ordinary administrators from assigning or revoking elevated system roles' do
      privileged = create(:system_role, :system, code: 'super_admin')
      normal = create(:system_role, :system, code: 'cashier')

      get new_admin_user_path
      expect(response.body).not_to include("value=\"#{privileged.id}\"")

      post admin_users_path, params: {
        user: { email: 'elevated@example.com', user_type: 'employee',
                theme: Theme::DEFAULT, system_role_ids: ['', privileged.id.to_s] }
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(User.exists?(email: 'elevated@example.com')).to be(false)
      expect(Nokogiri::HTML(response.body).at_css('p[data-server-field-error]')).to be_present

      target = add_member(create(:user, email: 'protected@example.com'))
      create(:user_role, user: target, system_role: privileged)
      patch admin_user_path(target), params: {
        user: { system_role_ids: ['', normal.id.to_s], username: 'malicious-update' }
      }
      expect(response).to have_http_status(:forbidden)
      expect(target.reload.username).not_to eq('malicious-update')
      expect(target.user_roles.active.exists?(system_role: privileged)).to be(true)
    end

    it 'prevents administrators from editing an existing elevated account' do
      protected_role = create(:system_role, :system, code: 'super_admin')
      privileged = add_member(create(:user, email: 'privileged@example.com'))
      create(:user_role, user: privileged, system_role: protected_role)

      get edit_admin_user_path(privileged)
      expect(response).to have_http_status(:forbidden)

      patch admin_user_path(privileged), params: { user: { email: 'changed@example.com' } }
      expect(response).to have_http_status(:forbidden)
      expect(privileged.reload.email).to eq('privileged@example.com')
    end

    it 'allows superadministrators to assign administrative roles' do
      super_role = create(:system_role, :system, code: 'super_admin')
      create(:user_role, user: admin_user, system_role: super_role)
      get new_admin_user_path
      expect(response.body).to include("value=\"#{super_role.id}\"")

      post admin_users_path, params: {
        user: { email: 'authorized@example.com', user_type: 'employee', theme: Theme::DEFAULT,
                system_role_ids: ['', super_role.id.to_s] }
      }
      expect(response).to redirect_to(admin_users_path)
      created = User.find_by!(email: 'authorized@example.com')
      expect(created.user_roles.active.exists?(system_role: super_role)).to be(true)
    end

    it 'reassigns a soft-deleted system role without leaving it revoked' do
      staff = create(:system_role, :system, code: 'staff')
      target = add_member(create(:user, email: 'revoked@example.com'))
      previous = create(:user_role, user: target, system_role: staff, deleted_at: 1.day.ago)

      get edit_admin_user_path(target)
      expect(Nokogiri::HTML(response.body).at_css("input#user_role_#{staff.id}[checked]")).to be_nil

      patch admin_user_path(target), params: {
        user: { system_role_ids: ['', staff.id.to_s] }
      }
      expect(response).to redirect_to(admin_user_path(target))
      expect(previous.reload.deleted_at).to be_present
      expect(target.user_roles.active.where(system_role: staff).count).to eq(1)
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

    it 'does not accept forged administrative password changes' do
      target = add_member(create(:user, password: 'originalpassword123'))
      patch admin_user_path(target), params: {
        user: { password: 'hackedpassword123', password_confirmation: 'hackedpassword123' }
      }
      expect(target.reload.valid_password?('originalpassword123')).to be(true)
      expect(target.valid_password?('hackedpassword123')).to be(false)
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

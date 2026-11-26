# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'System roles directory redesign', type: :request do
  let!(:actor) { create(:user, :english) }
  let!(:organization) { create(:organization) }
  let!(:super_role) { create(:system_role, :system, code: 'super_admin') }

  before do
    create(:organization_membership, organization:, user: actor)
    create(:user_role, user: actor, organization:, system_role: super_role)
    sign_in actor
  end

  it 'shows the approved directory without changing role card navigation' do
    cashier = create(:system_role, name: 'Cashier Operations', code: 'cashier_operations')

    get system_roles_path

    page = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(page.at_css('#role-directory-filters-heading')).to be_present
    expect(page.at_css('#role-directory-results-heading')).to be_present
    expect(page.at_css("[data-role-card][href='#{system_role_path(cashier)}']")).to be_present
    expect(page.css('.role-directory-help .promotion-help-trigger').size).to eq(4)
    expect(page.at_css('#new-role-dialog[data-controller="system-role-create"]')).to be_present
    expect(page.at_css('#system_roles_per_page')).to be_present
  end

  it 'filters the real roles by text and type without losing original card actions' do
    cashier = create(:system_role, name: 'Cashier Operations', code: 'cashier_operations', role_type: :branch)
    create(:system_role, name: 'Inventory Operations', code: 'inventory_operations', role_type: :system)

    get system_roles_path, params: { search: 'cashier', role_type: 'branch' }

    page = Nokogiri::HTML(response.body)
    expect(page.css('[data-role-card]').size).to eq(1)
    expect(page.at_css('[data-role-card]')['href']).to eq(system_role_path(cashier))
    expect(page.at_css('input[name="search"]')['value']).to eq('cashier')
    expect(page.at_css('select[name="role_type"] option[selected]')['value']).to eq('branch')
  end

  it 'escapes SQL wildcard characters in the search query' do
    create(:system_role, name: 'Warehouse Operations', code: 'warehouse_operations')

    get system_roles_path, params: { search: '%' }

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css('[data-role-card]')).to be_empty
  end

  it 'ignores unknown sort and type options rather than injecting SQL' do
    get system_roles_path, params: { sort: 'name; DROP TABLE system_roles', role_type: 'unknown' }

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('select[name="sort"] option[selected]')['value']).to eq('name')
  end

  it 'shows New Role to a seeded administrator and creates only an inactive role' do
    administrator_role = create(:system_role, :system, code: 'administrator')
    administrator = create(:user, :english)
    create(:organization_membership, organization:, user: administrator)
    create(:user_role, user: administrator, organization:, system_role: administrator_role)
    create(:permission, code: 'roles.create')
    sign_in administrator

    get system_roles_path
    expect(Nokogiri::HTML(response.body).at_css('#new-role-dialog')).to be_present
    expect(response.body).to include('aria-controls="new-role-dialog"')

    get new_system_role_path
    expect(response).to have_http_status(:ok)

    post system_roles_path, params: {
      role_modal: '1', permission_ids: [''],
      system_role: { name: 'Assistant supervisor', code: 'assistant_supervisor',
                     role_type: 'branch', status: 'inactive' }
    }
    role = SystemRole.find_by!(code: 'assistant_supervisor')
    expect(role).to be_inactive
    expect(response).to redirect_to(system_role_path(role))

    get status_review_system_role_path(role, target: 'active')
    expect(response).to have_http_status(:forbidden)
  end

  it 'hides New Role after the administrator loses its explicit creation grant' do
    admin_role = create(:system_role, :system, code: 'administrator')
    ordinary = create(:user, :english)
    create(:organization_membership, organization:, user: ordinary)
    create(:user_role, user: ordinary, organization:, system_role: admin_role)
    permission = create(:permission, code: 'roles.create')
    admin_role.system_role_permissions.where(permission:).delete_all
    sign_in ordinary

    get system_roles_path
    expect(Nokogiri::HTML(response.body).at_css('#new-role-dialog')).to be_nil

    post system_roles_path, params: {
      system_role: { name: 'Unapproved role', role_type: 'system', status: 'inactive' }
    }
    expect(response).to have_http_status(:forbidden)
    expect(SystemRole.find_by(name: 'Unapproved role')).to be_nil
  end

  it 'hides the creation modal from an ordinary administrator' do
    admin_role = create(:system_role, :system, code: 'administrator')
    ordinary = create(:user, :english)
    create(:organization_membership, organization:, user: ordinary)
    create(:user_role, user: ordinary, organization:, system_role: admin_role)
    sign_in ordinary

    get system_roles_path

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('#new-role-dialog')).to be_nil
    expect(response.body).not_to include('aria-controls="new-role-dialog"')
  end

  it 'creates an inactive role from the modal and redirects to permission management' do
    post system_roles_path, params: {
      role_modal: '1', permission_ids: [''],
      system_role: { name: 'Shift Supervisor', code: 'shift_supervisor',
                     role_type: 'branch', status: 'inactive', description: 'Shift operations' }
    }

    role = SystemRole.find_by!(code: 'shift_supervisor')
    expect(role).to be_inactive
    expect(role.permissions).to be_empty
    expect(response).to redirect_to(system_role_path(role))
  end

  it 're-renders validation errors inside the Turbo modal without persisting the role' do
    post system_roles_path,
         params: { role_modal: '1', permission_ids: [''],
                   system_role: { name: '', code: 'invalid-code', role_type: 'branch', status: 'inactive' } },
         headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    expect(response.body).to include('target="new-role-dialog"')
    expect(response.body).to include('role-create-input--invalid')
    expect(SystemRole.find_by(code: 'invalid-code')).to be_nil
  end
end

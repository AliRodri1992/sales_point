# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'System role editor', type: :request do
  let!(:admin_role) { create(:system_role, :system, code: 'super_admin') }
  let!(:admin) { create(:user, :english) }
  let!(:role) { create(:system_role, :system, name: 'Operations', code: 'operations') }
  let!(:permission) { create(:permission, code: 'suppliers.contacts.create', module_name: 'Proveedores') }

  before do
    create(:organization_membership, user: admin)
    create(:user_role, user: admin, system_role: admin_role)
    sign_in admin
  end

  def document
    Nokogiri::HTML(response.body)
  end

  it 'paginates roles deterministically and clamps out-of-range pages' do
    create_list(:system_role, 10, :system)
    get system_roles_path(per_page: 5, page: 2)
    expect(document.css('[data-role-card]').size).to eq(5)
    expect(document.at_css('span[aria-current="page"]').text).to eq('2')

    get system_roles_path(per_page: 5, page: 999)
    expect(document.css('[data-role-card]').size).to eq(2)
    expect(document.at_css('span[aria-current="page"]').text).to eq('3')
  end

  it 'preserves selected permissions after an invalid create' do
    post system_roles_path, params: { system_role: { name: '' }, permission_ids: [permission.id] }
    expect(response).to have_http_status(:unprocessable_content)
    expect(document.at_css("#permission_#{permission.id}").key?('checked')).to be(true)
  end

  it 'groups the real actions under their module and resource' do
    get new_system_role_path
    group = document.css('details').find { |node| node.text.include?('Suppliers') }
    expect(group.text).to include('Contacts', 'Create')
    expect(group.at_css("#permission_#{permission.id}")).to be_present
  end

  it 'updates role details and permissions together without changing its type or code' do
    patch system_role_path(role), params: {
      system_role: { name: 'New operations', description: 'Updated',
                     code: 'super_admin', role_type: 'branch' }, permission_ids: [permission.id]
    }
    expect(response).to redirect_to(system_role_path(role))
    expect(role.reload).to have_attributes(
      name: 'New operations', status: 'active', code: 'operations', role_type: 'system'
    )
    expect(role.permissions).to contain_exactly(permission)
  end

  it 'preserves permissions when updating only metadata through the API' do
    create(:system_role_permission, system_role: role, permission:)
    patch system_role_path(role), params: { system_role: { description: 'Updated details' } }
    expect(response).to redirect_to(system_role_path(role))
    expect(role.permissions.reload).to contain_exactly(permission)
  end

  it 'does not change status through the metadata endpoint' do
    patch system_role_path(role), params: { system_role: { status: 'inactive' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(role.reload).to be_active
    expect(document.at_css('select[name="target"] option')['value']).to eq('inactive')
  end

  it 'keeps existing permissions when role validation fails during update' do
    create(:system_role_permission, system_role: role, permission:)
    patch system_role_path(role), params: { system_role: { name: '' }, permission_ids: [] }
    expect(response).to have_http_status(:unprocessable_content)
    expect(role.reload.name).to eq('Operations')
    expect(role.permissions).to contain_exactly(permission)
  end

  it 'rejects inactive, missing and malformed permission ids without partially removing access' do
    create(:system_role_permission, system_role: role, permission:)
    inactive = create(:permission, status: :inactive)
    [inactive.id, Permission.maximum(:id) + 100, "#{permission.id}invalid", { invalid: 'value' }].each do |invalid|
      patch permissions_system_role_path(role), params: { permission_ids: [invalid] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(role.permissions.reload).to contain_exactly(permission)
    end
  end

  it 'accepts repeated ids once and supports removing then restoring a permission' do
    patch permissions_system_role_path(role), params: { permission_ids: [permission.id, permission.id] }
    expect(response).to have_http_status(:redirect)
    expect(role.permissions.reload).to contain_exactly(permission)
    patch permissions_system_role_path(role), params: { permission_ids: [] }
    expect(role.permissions.reload).to be_empty
    patch permissions_system_role_path(role), params: { permission_ids: [permission.id] }
    expect(response).to have_http_status(:redirect)
    expect(role.permissions.reload).to contain_exactly(permission)
  end

  it 'renders invalid enum values as validation errors rather than crashing' do
    post system_roles_path, params: { system_role: { name: 'Invalid enum', role_type: 'bogus', status: 'bogus' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(SystemRole.find_by(name: 'Invalid enum')).to be_nil
  end

  it 'does not permit editing protected administrative roles through either route' do
    get edit_system_role_path(admin_role)
    expect(response).to have_http_status(:forbidden)
    patch system_role_path(admin_role), params: { system_role: { name: 'Changed' } }
    expect(response).to have_http_status(:forbidden)
  end

  it 'forbids non-administrators from creating, viewing and updating roles' do
    sign_in create(:user)
    get new_system_role_path
    expect(response).to have_http_status(:forbidden)
    get system_role_path(role)
    expect(response).to have_http_status(:forbidden)
    patch system_role_path(role), params: { system_role: { name: 'Changed' } }
    expect(response).to have_http_status(:forbidden)
  end
end

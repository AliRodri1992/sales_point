# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviewed role status changes', type: :request do
  let!(:admin) { create(:user, :english) }
  let!(:role) { create(:system_role, :system) }
  let!(:permission) { create(:permission, code: 'products.show') }

  before do
    create(:organization_membership, user: admin)
    create(:user_role, user: admin, system_role: create(:system_role, :system, code: 'super_admin'))
    create(:system_role_permission, system_role: role, permission:)
    sign_in admin
  end

  def review(target)
    get status_review_system_role_path(role, target:)
    Nokogiri::HTML(response.body).at_css('input[name="review_token"]')&.[]('value')
  end

  def change_status(target, **overrides)
    token = review(target)
    patch status_system_role_path(role), params: {
      target:, reason: 'Approved after review', review_token: token, confirmed: '1', **overrides
    }
  end

  it 'creates inactive roles and rejects attempts to bypass initial review' do
    post system_roles_path, params: { system_role: { name: 'New inactive role', role_type: 'system' } }
    expect(response).to have_http_status(:redirect)
    expect(SystemRole.find_by!(name: 'New inactive role')).to be_inactive
    post system_roles_path, params: { system_role: { name: 'Bypass', role_type: 'system', status: 'active' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(SystemRole.find_by(name: 'Bypass')).to be_nil
  end

  it 'shows review, persists reason and updates authorization in an existing session' do
    user = create(:user, :english)
    create(:user_role, user:, system_role: role)
    expect(user.permission?(permission.code)).to be(true)
    change_status('inactive')
    expect(response).to redirect_to(system_role_path(role))
    expect(user.permission?(permission.code)).to be(false)
    expect(role.status_events.last.reason).to eq('Approved after review')
    change_status('active')
    expect(response).to have_http_status(:redirect)
    expect(user.permission?(permission.code)).to be(true)
  end

  it 'rejects direct PATCH without review and direct DELETE' do
    patch status_system_role_path(role), params: { target: 'inactive', reason: 'Bypass', confirmed: '1' }
    expect(response).to have_http_status(:unprocessable_content)
    delete system_role_path(role)
    expect(response).to have_http_status(:unprocessable_content)
    expect(role.reload).to be_active
    expect(role.status_events).to be_empty
  end

  it 'enforces deactivation on the next operation without signing out the assigned user' do
    user = create(:user, :english)
    create(:organization_membership, user:, organization: admin.organization_memberships.first!.organization)
    create(:user_role, user:, system_role: role)
    %w[languages.access languages.index].each do |code|
      create(:system_role_permission, system_role: role, permission: create(:permission, code:))
    end
    sign_in user
    get admin_languages_path
    expect(response).to have_http_status(:ok)

    token = SystemRoles::StatusReview.new(role:, actor: admin, target: 'inactive').token
    SystemRoles::StatusTransition.new(role:, actor: admin, target: 'inactive', reason: 'Reviewed',
                                      review_token: token, confirmed: true).call!
    get admin_languages_path
    expect(response).to have_http_status(:forbidden)
  end

  it 'preserves reason and shows a useful error when confirmation is missing' do
    change_status('inactive', confirmed: '0')
    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('[role="alert"]').text).to include('Confirm')
    expect(document.at_css('textarea[name="reason"]').text.strip).to eq('Approved after review')
    expect(role.reload).to be_active
  end

  it 'lists archived roles separately and restores them without activating access' do
    change_status('inactive')
    change_status('deprecated')
    expect(role.reload).to be_deprecated
    get system_roles_path
    expect(Nokogiri::HTML(response.body).at_css("a[data-role-card][href='#{system_role_path(role)}']")).to be_nil
    get system_roles_path(filter: 'archived')
    expect(response.body).to include(role.name, 'Archived')
    get system_role_path(role)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Restore as inactive', 'Approved after review')
    patch permissions_system_role_path(role), params: { permission_ids: [] }
    expect(response).to have_http_status(:forbidden)
    change_status('inactive')
    expect(role.reload).to be_inactive
    expect(role.deleted_at).to be_nil
  end

  it 'explains the empty archived list without implying that no roles exist' do
    get system_roles_path(filter: 'archived')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('No archived roles')
  end

  it 'prevents activation without permissions and archiving with retained assignments' do
    create(:user_role, system_role: role)
    change_status('inactive')
    review('deprecated')
    expect(response.body).to include('Revoke or reassign')
    expect(response.body).not_to include('name="review_token"')
    role.system_role_permissions.destroy_all
    review('active')
    expect(response.body).to include('Assign at least one')
    expect(response.body).not_to include('name="review_token"')
  end

  it 'does not permit reviewing cross-organization changes or disclosing foreign users' do
    foreign_user = create(:user, username: 'ForeignPrivateName')
    create(:organization_membership, user: foreign_user)
    create(:user_role, user: foreign_user, system_role: role)

    review('inactive')
    expect(response).to have_http_status(:forbidden)
    expect(response.body).not_to include('ForeignPrivateName')
  end

  it 'lets an administrator explicitly remove an inactive assignment before archiving' do
    organization = admin.organization_memberships.first!.organization
    user = create(:user, :english)
    create(:organization_membership, user:, organization:)
    assignment = create(:user_role, user:, system_role: role)
    alternative = create(:system_role, :system, code: 'backup_operations')
    create(:user_role, user:, system_role: alternative)
    change_status('inactive')
    get edit_admin_user_path(user)
    expect(response).to have_http_status(:ok)
    input = Nokogiri::HTML(response.body).at_css("#user_role_#{role.id}")
    expect(input).to be_present
    expect(input.key?('checked')).to be(true)
    expect(response.body).to include('Inactive · grants no access.')
    patch admin_user_path(user), params: { user: { system_role_ids: [alternative.id.to_s] } }
    expect(response).to have_http_status(:redirect)
    expect(UserRole.with_deleted.find(assignment.id).deleted_at).to be_present
    change_status('deprecated')
    expect(response).to have_http_status(:redirect)
    expect(role.reload).to be_deprecated
  end

  it 'forbids nonadministrators and protects administrative status on both endpoints' do
    protected_role = admin.system_roles.first
    get status_review_system_role_path(protected_role, target: 'inactive')
    expect(response).to have_http_status(:forbidden)
    patch status_system_role_path(protected_role), params: { target: 'inactive' }
    expect(response).to have_http_status(:forbidden)
    sign_in create(:user)
    review('inactive')
    expect(response).to have_http_status(:forbidden)
    patch status_system_role_path(role), params: { target: 'inactive' }
    expect(response).to have_http_status(:forbidden)
  end
end

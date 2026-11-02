# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin branch role assignment management', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:admin) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:target) { create(:user) }
  let(:branch_role) { create(:system_role, :branch, code: 'cashier_branch') }
  let(:branch) { create(:branch, organization:) }

  before do
    create(:organization_membership, user: admin, organization:)
    create(:organization_membership, user: target, organization:)
    sign_in admin
  end

  it 'grants a branch role and makes the assigned branch available in the navbar' do
    patch admin_user_path(target), params: {
      user: { branch_role_assignments: ['', "#{branch.id}:#{branch_role.id}"] }
    }

    expect(response).to redirect_to(admin_user_path(target))
    expect(target.reload.user_roles.active.where(branch_id: branch.id).pluck(:system_role_id)).to eq([branch_role.id])

    sign_out admin
    sign_in target
    get admin_dashboard_path
    expect(response.body).to include(branch.name)
  end

  it 'replaces only local branch assignments, leaving foreign organization roles untouched' do
    foreign_branch = create(:branch, organization: other_organization)
    create(:organization_membership, user: target, organization: other_organization)
    create(:user_role, user: target, system_role: branch_role, branch:)
    foreign_role = create(:system_role, :branch, code: 'foreign_cashier')
    create(:user_role, user: target, system_role: foreign_role, branch: foreign_branch)

    patch admin_user_path(target), params: { user: { branch_role_assignments: [''] } }

    expect(response).to redirect_to(admin_user_path(target))
    expect(target.user_roles.active.pluck(:branch_id)).to eq([foreign_branch.id])
    expect(target.user_roles.find_by!(branch_id: branch).deleted_at).to be_present
  end

  it 'rejects forged branch and role values without saving partial edits' do
    forbidden_branch = create(:branch, organization: other_organization)
    inactive_branch = create(:branch, organization:, status: false)
    inactive_role = create(:system_role, :branch, :inactive, code: 'disabled_cashier')
    invalid_inputs = [
      "#{forbidden_branch.id}:#{branch_role.id}",
      "#{inactive_branch.id}:#{branch_role.id}",
      "#{branch.id}:#{inactive_role.id}",
      '1:abc'
    ]

    invalid_inputs.each do |token|
      patch admin_user_path(target), params: {
        user: { username: 'should_not_save', branch_role_assignments: ['', token] }
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(target.reload.username).not_to eq('should_not_save')
      expect(target.user_roles.active.where.not(branch_id: nil)).to be_empty
    end
  end

  it 'renders branch choices as checkboxes without altering the rest of the form' do
    get edit_admin_user_path(target)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('user[branch_role_assignments][]')
    expect(response.body).to include('data-controller="delta-select"')
    expect(response.body).not_to include('type="radio"')
  end
end

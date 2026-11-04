# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Retained inactive role assignments' do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:global_role) { create(:system_role, :system) }
  let(:branch_role) { create(:system_role, :branch) }
  let(:branch) { create(:branch, organization:) }

  def deactivate(role)
    role.assign_attributes(status: 'inactive')
    role.save!(context: :status_transition)
  end

  def save_assignments(**attributes)
    Users::AdminAccountWriter.new(user:, organization:, attributes:).save
  end

  it 'keeps a retained global assignment while editing and permits explicit removal' do
    assignment = create(:user_role, user:, system_role: global_role)
    deactivate(global_role)
    expect(save_assignments(system_role_ids: [global_role.id])).to be(true)
    expect(assignment.reload.deleted_at).to be_nil
    expect(save_assignments(system_role_ids: [''])).to be(true)
    expect(UserRole.with_deleted.find(assignment.id).deleted_at).to be_present
    expect(save_assignments(system_role_ids: [global_role.id])).to be(false)
  end

  it 'retains only existing inactive branch pairs and permits their removal' do
    assignment = create(:user_role, user:, system_role: branch_role, branch:)
    deactivate(branch_role)
    token = "#{branch.id}:#{branch_role.id}"
    expect(save_assignments(branch_role_assignments: [token])).to be(true)
    other = create(:branch, organization:, name: 'Another branch')
    expect(save_assignments(branch_role_assignments: [token, "#{other.id}:#{branch_role.id}"])).to be(false)
    expect(assignment.reload.deleted_at).to be_nil
    expect(save_assignments(branch_role_assignments: [''])).to be(true)
    expect(UserRole.with_deleted.find(assignment.id).deleted_at).to be_present
  end

  it 'rejects new inactive assignments at the model boundary' do
    deactivate(global_role)
    assignment = build(:user_role, user:, system_role: global_role)
    expect(assignment).not_to be_valid
    expect { assignment.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'permits retaining or removing an existing assignment on an archived branch' do
    assignment = create(:user_role, user:, system_role: branch_role, branch:)
    branch.update!(status: false, deleted_at: Time.current)
    expect(Users::BranchRoleAssignments.branch_options(user:, organization:)).to include(branch)
    expect(Users::BranchRoleAssignments.branch_options(user: User.new, organization:)).not_to include(branch)
    token = "#{branch.id}:#{branch_role.id}"
    expect(save_assignments(branch_role_assignments: [token])).to be(true)
    expect(save_assignments(branch_role_assignments: [''])).to be(true)
    expect(UserRole.with_deleted.find(assignment.id).deleted_at).to be_present
    expect(save_assignments(branch_role_assignments: [token])).to be(false)
  end

  it 'rechecks under lock when an assignment holds a stale active role object' do
    assignment = build(:user_role, user:, system_role: global_role)
    other_copy = SystemRole.find(global_role.id)
    deactivate(other_copy)
    expect(global_role).to be_active
    expect { assignment.save! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.user_roles).to be_empty
  end
end

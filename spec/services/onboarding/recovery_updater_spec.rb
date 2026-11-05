# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Onboarding::RecoveryUpdater, type: :service do
  let(:organization) { create(:organization, :with_settings) }
  let(:user) { create(:user) }
  let(:branch) { create(:branch, organization:) }

  def recover(intent, record, values, selected_branch = branch)
    described_class.call(organization:, user:, intent:, record:, branch: selected_branch,
                         params: ActionController::Parameters.new(recovery: values))
  end

  it 'creates one register and preserves the first one on repeated submissions' do
    expect do
      expect(recover('terminal', Terminal.new, { name: 'Main register' })).to be(true)
      expect(recover('terminal', Terminal.new, { name: 'Duplicate' })).to be(true)
    end.to change(Terminal, :count).by(1)
    expect(branch.terminals.first.name).to eq('Main register')
    expect(organization.onboarding_audits.where(section: 'terminals').count).to eq(1)
  end

  it 'does not reuse the code of a deleted register or restore it silently' do
    old = create(:terminal, branch:, code: 'POS-001')
    old.destroy!
    expect(recover('terminal', Terminal.new, { name: 'New register' })).to be(true)
    expect(branch.terminals.active_records.first.code).to eq('POS-002')
    expect(old.reload.deleted_at).to be_present
  end

  it 'rejects a branch from another organization' do
    foreign = create(:branch)
    record = Terminal.new
    expect(recover('terminal', record, { name: 'Register' }, foreign)).to be(false)
    expect(record.errors[:base]).to be_present
    expect(foreign.terminals.count).to eq(0)
  end

  it 'creates a profile for the current account without changing its permissions' do
    create(:organization_membership, organization:, user:)
    record = organization.employees.build
    roles = user.user_roles.count
    expect(recover('team', record, { first_name: 'Ana', last_name: 'Audit' })).to be(true)
    expect(record).to have_attributes(email: user.email, organization_id: organization.id, status: 'active')
    expect(user.reload.employee).to eq(record)
    expect(user.user_roles.count).to eq(roles)
    expect(recover('team', Employee.new, { first_name: 'Duplicate', last_name: 'Name' })).to be(true)
    expect(organization.employees.count).to eq(1)
  end

  it 'does not reactivate an existing inactive profile' do
    create(:employee, organization:, email: user.email, status: :inactive)
    record = Employee.new
    expect(recover('team', record, { first_name: 'Ana', last_name: 'Audit' })).to be(false)
    expect(record.errors[:base]).to be_present
    expect(organization.employees.active).to be_empty
  end

  it 'reports validation errors without recording progress or leaving partial registers' do
    record = Terminal.new
    expect(recover('terminal', record, { name: '' })).to be(false)
    expect(record.errors[:name]).to be_present
    expect(branch.terminals).to be_empty
    expect(organization.onboarding_audits).to be_empty
  end

  it 'requires selecting an active branch when recovering a register' do
    record = Terminal.new
    expect(recover('terminal', record, { name: 'Register' }, nil)).to be(false)
    expect(record.errors[:base]).to be_present
  end

  it 'keeps an existing employee association while creating an organization profile' do
    existing = create(:employee)
    user.update!(employee: existing)
    record = Employee.new
    expect(recover('team', record, { first_name: 'Ana', last_name: 'Review' })).to be(true)
    expect(record.organization).to eq(organization)
    expect(user.reload.employee).to eq(existing)
  end

  it 'rolls back the employee profile if its account cannot be linked' do
    user.status = nil
    record = Employee.new
    expect(recover('team', record, { first_name: 'Ana', last_name: 'Review' })).to be(false)
    expect(record.errors[:base]).to be_present
    expect(organization.employees).to be_empty
  end
end

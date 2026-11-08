# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Branches::TransitionStatus do
  let(:organization) { create(:organization) }
  let(:actor) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:branch) { create(:branch, organization:, name: 'Main office') }

  before { create(:organization_membership, organization:, user: actor) }

  it 'suspends a branch and records an immutable audit event' do
    branch
    expect do
      described_class.call(branch:, actor:, to: 'suspended', reason: 'Temporary maintenance')
    end.to change(BranchStatusTransition, :count).by(1)

    expect(branch.reload).to be_suspended
    expect(branch.status).to be(false)
    expect(branch.branch_status_transitions.count).to eq(2)
    entry = branch.branch_status_transitions.last
    expect(entry).to have_attributes(from_status: 'active', to_status: 'suspended',
                                     reason: 'Temporary maintenance', changed_by: actor)
  end

  it 'activates a prepared branch with an authorized administrator and complete configuration' do
    configured = create(:organization, :with_settings)
    create(:organization_membership, organization: configured, user: actor)
    office = create(:branch, organization: configured, operational_state: 'preparing')

    expect do
      described_class.call(branch: office, actor:, to: 'active', reason: 'Ready to open')
    end.to change { office.branch_status_transitions.count }.by(1)

    expect(office.reload).to be_active
    expect(office.status).to be(true)
  end

  it 'requires disabling all terminals before suspension' do
    terminal = create(:terminal, branch:, status: 'active')

    expect do
      described_class.call(branch:, actor:, to: 'suspended', reason: 'Maintenance')
    end.to raise_error(described_class::InvalidTransition)

    terminal.update!(status: 'inactive')
    expect do
      described_class.call(branch:, actor:, to: 'suspended', reason: 'Maintenance')
    end.not_to raise_error
  end

  it 'requires a reason for every transition' do
    expect do
      described_class.call(branch:, actor:, to: 'suspended', reason: ' ')
    end.to raise_error(described_class::InvalidTransition)
    expect(branch.reload).to be_active
  end

  it 'rejects a transition requested by a non-administrator' do
    outsider = create(:user)
    expect do
      described_class.call(branch:, actor: outsider, to: 'suspended', reason: 'Unauthorized')
    end.to raise_error(described_class::InvalidTransition)
    expect(branch.reload).to be_active
  end

  it 'protects the address of a permanently closed branch from edits and deletion' do
    described_class.call(branch:, actor:, to: 'closed', reason: 'Site closed permanently')

    address = branch.address
    expect(address.update(city: 'Another city')).to be(false)
    expect(address.errors[:base]).to be_present
    expect(address.destroy).to be(false)
    expect(address.reload).to be_persisted
  end

  it 'does not permit reopening a closed branch' do
    described_class.call(branch:, actor:, to: 'closed', reason: 'Permanent closure')
    expect(branch.reload).to be_closed
    expect do
      described_class.call(branch:, actor:, to: 'active', reason: 'Attempt to reopen')
    end.to raise_error(described_class::InvalidTransition)
  end
end

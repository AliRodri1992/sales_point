# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Branches::LifecycleRequirements do
  let(:organization) { create(:organization, :with_settings) }
  let(:actor) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:branch) { create(:branch, organization:, name: 'Central') }

  before { create(:organization_membership, organization:, user: actor) }

  it 'recognizes an authorized organization administrator as a manager' do
    requirements = described_class.new(branch:, actor:)
    expect(requirements.activation.values).to all(be(true))
  end

  it 'requires a valid address and active base currency for activation' do
    office = create(:branch, organization:, operational_state: 'preparing', name: 'New office')
    office.address.update!(street: 'Reforma')
    office.address.street = ''

    requirements = described_class.new(branch: office, actor:)
    expect(requirements.activation[:address]).to be(false)
    organization.organization_settings.first.base_currency.update!(active: false)
    expect(requirements.activation[:currency]).to be(false)
  end

  it 'blocks suspension while a terminal is enabled' do
    create(:terminal, branch:, status: 'active')
    requirements = described_class.new(branch:, actor:)
    expect(requirements.suspension_blockers).to include(:active_terminals)
  end

  it 'reports the precise inventory and personnel blockers for closure' do
    create(:inventory, branch:, organization:, stock: 8)
    teammate = create(:user)
    create(:organization_membership, organization:, user: teammate)
    create(:user_role, user: teammate, branch:, system_role: create(:system_role, :branch))

    requirements = described_class.new(branch:, actor:)
    expect(requirements.closure_blockers).to include(:outstanding_stock, :assigned_team)
  end

  it 'protects the last active branch of an operating organization' do
    organization.update!(onboarding_status: :completed)
    requirements = described_class.new(branch:, actor:)
    expect(requirements.suspension_blockers).to include(:last_active_branch)
    expect(requirements.closure_blockers).to include(:last_active_branch)
  end
end

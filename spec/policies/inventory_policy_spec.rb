# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventoryPolicy do
  it 'requires both a user and an organization before looking up grants' do
    inventory = create(:inventory)
    expect(described_class.permitted_roles(nil, inventory.organization, described_class::READ_KEYS)).to be_empty
    expect(described_class.permitted_roles(create(:user), nil, described_class::READ_KEYS)).to be_empty
  end

  it 'hides inventory from a user without membership in the selected organization' do
    stock = create(:inventory)
    outsider = create(:user)
    CurrentOrganizationAccess.set(organization: stock.organization) do
      expect(described_class::Scope.new(outsider, Inventory.all).resolve).to be_empty
    end
  end

  it 'rejects a foreign inventory even for an administrator in the selected organization' do
    organization = create(:organization)
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, user: admin, organization:)
    foreign_stock = create(:inventory)

    CurrentOrganizationAccess.set(organization:) do
      expect(described_class.new(admin, foreign_stock)).not_to be_show
    end
  end
end

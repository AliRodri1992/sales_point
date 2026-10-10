# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_examples')

RSpec.describe SupplierExamples do
  let!(:administrator) { create(:user, email: 'administrador@delta.com') }

  it 'creates twenty organization-owned suppliers and their primary contacts' do
    described_class.seed!

    organization = Organization.find_by!(tax_id: described_class::ORGANIZATION_TAX_ID)
    expect(organization.suppliers.count).to eq(20)
    expect(organization.suppliers.where(status: :inactive).count).to eq(4)
    expect(organization.suppliers.joins(:contacts).count).to eq(20)
    expect(organization.organization_memberships.where(user: administrator, status: :active).count).to eq(1)
  end

  it 'does not duplicate suppliers, contacts or memberships when run twice' do
    2.times { described_class.seed! }

    organization = Organization.find_by!(tax_id: described_class::ORGANIZATION_TAX_ID)
    expect(organization.suppliers.count).to eq(20)
    expect(Contact.where(contactable: organization.suppliers).count).to eq(20)
    expect(organization.organization_memberships.where(user: administrator).count).to eq(1)
  end
end

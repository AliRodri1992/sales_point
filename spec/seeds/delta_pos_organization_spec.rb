# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_examples')

RSpec.describe SupplierExamples, type: :model do
  before do
    create(:user, email: 'administrador@delta.com')
    create(:currency, code: 'MXN', numeric_code: '484')
    allow(described_class).to receive(:create_suppliers_for)
  end

  it 'creates Delta POS with MXN as its base currency' do
    described_class.seed!

    organization = Organization.find_by!(tax_id: described_class::ORGANIZATION_TAX_ID)
    expect(organization.name).to eq('Delta POS')
    expect(organization.organization_settings.first.base_currency.code).to eq('MXN')
  end

  it 'does not duplicate Delta POS or its administrator membership' do
    2.times { described_class.seed! }

    organization = Organization.find_by!(tax_id: described_class::ORGANIZATION_TAX_ID)
    expect(Organization.where(tax_id: described_class::ORGANIZATION_TAX_ID).count).to eq(1)
    expect(OrganizationMembership.where(organization:).count).to eq(1)
  end
end

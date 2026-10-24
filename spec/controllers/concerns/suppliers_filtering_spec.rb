# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::SuppliersFiltering do
  let(:organization) { create(:organization) }
  let(:actor) { create(:user) }
  let(:handler) do
    Class.new do
      include Admin::SuppliersFiltering

      attr_accessor :params, :actor, :organization

      def current_user = actor
      def current_organization = organization
    end.new
  end

  before do
    handler.actor = actor
    handler.organization = organization
    handler.params = ActionController::Parameters.new
    allow(actor).to receive(:admin?).and_return(false)
    allow(actor).to receive(:permission?).with('suppliers.view').and_return(false)
  end

  it 'restricts basic status filtering without full supplier view permission' do
    active = create(:supplier, organization:, status: :active)
    inactive = create(:supplier, organization:, status: :inactive)
    handler.params = ActionController::Parameters.new(status: 'active')

    expect(handler.send(:apply_filters, organization.suppliers)).to include(active)
    expect(handler.send(:apply_filters, organization.suppliers)).not_to include(inactive)
  end

  it 'ignores unrecognized status values rather than leaking unscoped results' do
    active = create(:supplier, organization:, status: :active)
    inactive = create(:supplier, organization:, status: :inactive)
    handler.params = ActionController::Parameters.new(status: 'unknown')

    expect(handler.send(:apply_filters, organization.suppliers)).to include(active, inactive)
  end

  it 'limits searches to code and supplier name when full access is absent' do
    matching = create(:supplier, organization:, name: 'Special Catalog Supplier')
    other = create(:supplier, organization:, name: 'Ordinary Vendor')
    handler.params = ActionController::Parameters.new(search: 'Special Catalog')

    expect(handler.send(:apply_filters, organization.suppliers)).to include(matching)
    expect(handler.send(:apply_filters, organization.suppliers)).not_to include(other)
  end

  it 'never interpolates arbitrary numeric columns into SQL' do
    scope = organization.suppliers
    handler.params = ActionController::Parameters.new('secret_min' => '0')

    expect(handler.send(:apply_numeric_bound, scope, 'secret', 'min')).to eq(scope)
  end

  it 'never interpolates arbitrary date columns into SQL' do
    scope = organization.suppliers
    handler.params = ActionController::Parameters.new('secret_from' => '2026-10-24')

    expect(handler.send(:apply_date_bound, scope, 'secret', 'from')).to eq(scope)
  end

  it 'accepts a valid organization-managed fiscal-regime selector only' do
    regime = create(:sat_fiscal_regime)
    handler.instance_variable_set(:@supplier_regimes, [regime])
    handler.params = ActionController::Parameters.new(sat_fiscal_regime_id: regime.id.to_s)

    expect(handler.send(:valid_regime_filter?)).to be(true)
    handler.params = ActionController::Parameters.new(sat_fiscal_regime_id: '987654321')
    expect(handler.send(:valid_regime_filter?)).to be(false)
  end
end

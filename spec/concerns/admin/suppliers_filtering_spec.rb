# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::SuppliersFiltering do
  let(:actor) { instance_double(User, admin?: false) }
  let(:filtering) do
    Class.new do
      include Admin::SuppliersFiltering

      attr_accessor :params, :current_user
    end.new
  end

  before do
    allow(actor).to receive(:permission?).and_return(false)
    filtering.current_user = actor
    filtering.params = ActionController::Parameters.new
  end

  it 'does not search tax identifiers when only general supplier access is granted' do
    allow(actor).to receive(:permission?).with('suppliers.view').and_return(true)
    filtering.params = ActionController::Parameters.new(search: 'XAXX010101000')

    sql = filtering.send(:apply_search_filter, Supplier.all).to_sql

    expect(sql).to include('suppliers.name ILIKE')
    expect(sql).to include('suppliers.email ILIKE')
    expect(sql).not_to include('suppliers.rfc ILIKE')
  end

  it 'allows searching tax identifiers when fiscal viewing is permitted' do
    allow(actor).to receive(:permission?).with('suppliers.fiscal.view').and_return(true)
    filtering.params = ActionController::Parameters.new(search: 'XAXX010101000')

    expect(filtering.send(:apply_search_filter, Supplier.all).to_sql).to include('suppliers.rfc ILIKE')
  end

  it 'does not apply fiscal and commercial filters without their granular permissions' do
    allow(actor).to receive(:permission?).with('suppliers.view').and_return(true)
    filtering.params = ActionController::Parameters.new(
      credit: 'yes', credit_limit_min: '100', person_type: 'company', sat_fiscal_regime_id: '1'
    )

    sql = filtering.send(:apply_filters, Supplier.all).to_sql

    expect(sql).not_to include('credit_limit')
    expect(sql).not_to include('person_type')
    expect(sql).not_to include('sat_fiscal_regime_id')
  end

  it 'does not eliminate records when the currency filter is All' do
    allow(actor).to receive(:permission?).with('suppliers.view').and_return(true)
    allow(actor).to receive(:permission?).with('suppliers.commercial.view').and_return(true)
    filtering.params = ActionController::Parameters.new(currency: 'all')

    expect(filtering.send(:apply_filters, Supplier.all).to_sql).not_to include('1=0')
  end

  it 'restricts sorting on hidden fiscal fields' do
    listing = Class.new do
      include Admin::SuppliersListing

      attr_accessor :current_user
    end.new
    listing.current_user = actor

    expect(listing.send(:restricted_sort?, 'suppliers.rfc')).to be(true)
    expect(listing.send(:restricted_sort?, 'suppliers.name')).to be(false)

    allow(actor).to receive(:permission?).with('suppliers.fiscal.view').and_return(true)
    expect(listing.send(:restricted_sort?, 'suppliers.rfc')).to be(false)
  end
end

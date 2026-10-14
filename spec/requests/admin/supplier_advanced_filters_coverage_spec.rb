# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier advanced catalog filters', type: :request do
  let(:organization) { create(:organization) }
  let(:actor) { create(:user, :english) }
  let(:supplier) do
    create(:supplier, organization:, classification: 'manufacturer', person_type: 'company',
                      credit_days: 15, credit_limit: 1000, minimum_order_amount: 50,
                      discount_percent: 10, status: :active)
  end

  before do
    create(:organization_membership, organization:, user: actor)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    supplier
    sign_in actor
  end

  {
    'active state' => { status: 'active' },
    'inactive state' => { status: 'inactive' },
    'manufacturer category' => { classification: 'manufacturer' },
    'invalid category' => { classification: 'fake' },
    'company tax status' => { person_type: 'company' },
    'individual tax status' => { person_type: 'individual' },
    'credit present' => { credit: 'yes' },
    'no credit' => { credit: 'no' },
    'unknown credit option' => { credit: 'maybe' },
    'currency filter' => { currency: 'MXN' },
    'invalid currency' => { currency: 'ZZZ' },
    'invalid responsible user' => { responsible_user_id: 'abc' },
    'foreign responsible user' => { responsible_user_id: '999999999' },
    'invalid fiscal regime' => { sat_fiscal_regime_id: 'untrusted' },
    'numeric minimum days' => { credit_days_min: '10' },
    'numeric maximum days' => { credit_days_max: '20' },
    'numeric minimum credit limit' => { credit_limit_min: '100' },
    'numeric maximum credit limit' => { credit_limit_max: '2000' },
    'numeric minimum order' => { minimum_order_amount_min: '10' },
    'numeric maximum order' => { minimum_order_amount_max: '100' },
    'numeric minimum discount' => { discount_percent_min: '2' },
    'numeric maximum discount' => { discount_percent_max: '20' },
    'negative numeric bound' => { credit_days_min: '-3' },
    'invalid numeric bound' => { discount_percent_max: 'invalid' },
    'numeric oversized bound' => { credit_limit_min: '100000000000000' },
    'created date from' => { created_at_from: '2025-01-01' },
    'created date to' => { created_at_to: '2027-01-01' },
    'updated date from' => { updated_at_from: '2025-01-01' },
    'updated date to' => { updated_at_to: '2027-01-01' },
    'malformed date' => { created_at_from: 'not-a-date' }
  }.each do |label, filters|
    it "accepts #{label} without exposing other organizations" do
      get admin_suppliers_path, params: filters

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Foreign Organization Supplier')
    end
  end

  it 'filters by the actual supplier currency' do
    get admin_suppliers_path, params: { currency: supplier.currency.code.downcase }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(supplier.name)
  end

  it 'filters by an organization-owned responsible user' do
    supplier.update!(responsible_user: actor)
    get admin_suppliers_path, params: { responsible_user_id: actor.id }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(supplier.name)
  end

  it 'applies a numeric minimum and maximum simultaneously' do
    get admin_suppliers_path, params: { credit_days_min: '10', credit_days_max: '20' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(supplier.name)
  end

  it 'filters between two creation dates' do
    get admin_suppliers_path, params: {
      created_at_from: 1.day.ago.to_date.iso8601,
      created_at_to: 1.day.from_now.to_date.iso8601
    }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(supplier.name)
  end
end

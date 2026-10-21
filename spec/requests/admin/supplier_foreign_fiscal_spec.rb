# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Foreign supplier fiscal registration', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  it 'creates a foreign supplier without a Mexican RFC' do
    country = create(:country, iso_alpha2: 'US')
    post admin_suppliers_path, params: { supplier: attributes_for(:supplier).merge(
      rfc: '', foreign_tax_id: 'US-98-7654321', currency_id: create(:currency).id,
      addresses_attributes: { '0' => {
        country_id: country.id, street: 'Main St', city: 'Austin',
        state: 'TX', postal_code: '78701', purpose: 'fiscal', primary: true
      } }
    ) }

    expect(response).to redirect_to(admin_suppliers_path)
    saved = Supplier.order(:id).last
    expect(saved.rfc).to be_nil
    expect(saved.foreign_tax_id).to eq('US-98-7654321')
  end
end

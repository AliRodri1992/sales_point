# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier fiscal address step validation', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }
  let(:country) { Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX') }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  def fiscal_address(attributes = {})
    {
      street: 'Avenida Reforma', exterior_number: '125', neighborhood: 'Centro',
      city: 'Ciudad de México', state: 'CDMX', country_id: country.id, postal_code: '06000'
    }.merge(attributes)
  end

  it 'returns model errors per address field without persisting the supplier or address' do
    address_count = Address.count
    expect do
      post validate_fiscal_address_admin_suppliers_path,
           params: { address: fiscal_address(street: '', exterior_number: '',
                                             neighborhood: '', city: '', state: '', postal_code: '12') },
           as: :json
    end.not_to change(Supplier, :count)

    expect(Address.count).to eq(address_count)
    expect(response).to have_http_status(:unprocessable_content)
    errors = response.parsed_body.fetch('errors')
    expect(errors.keys).to include('street', 'exterior_number', 'neighborhood', 'city', 'state', 'postal_code')
    expect(errors['postal_code']).to be_present
  end

  it 'maps a missing country association to the country selector error' do
    post validate_fiscal_address_admin_suppliers_path,
         params: { address: fiscal_address(country_id: '') },
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch('errors').fetch('country_id')).to be_present
  end

  it 'accepts valid Mexican fiscal addresses using the Address model rules' do
    post validate_fiscal_address_admin_suppliers_path, params: { address: fiscal_address }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('valid' => true)
  end

  it 'applies country-specific rules rather than requiring Mexican-only fields' do
    emirates = Country.find_by(iso_alpha2: 'AE') || create(:country, iso_alpha2: 'AE')
    post validate_fiscal_address_admin_suppliers_path,
         params: { address: fiscal_address(country_id: emirates.id, exterior_number: '',
                                           neighborhood: '', state: '', postal_code: '') },
         as: :json

    expect(response).to have_http_status(:ok)
  end

  it 'denies validation requests from unauthorized users' do
    sign_out user
    post validate_fiscal_address_admin_suppliers_path, params: { address: fiscal_address }, as: :json

    expect(response).to redirect_to(new_user_session_path)
  end
end

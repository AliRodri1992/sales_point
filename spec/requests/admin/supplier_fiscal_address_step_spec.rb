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

  context 'when the user prefers Spanish' do
    let(:user) { create(:user, :spanish) }

    it 'returns complete localized field messages for the address step' do
      post validate_fiscal_address_admin_suppliers_path,
           params: { address: fiscal_address(street: '', postal_code: '12') },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.fetch('errors')).to include(
        'street' => ['Calle no puede estar vacío'],
        'postal_code' => ['Código postal no es válido']
      )
    end

    it 'uses the country label and blank-message format for an unselected country' do
      post validate_fiscal_address_admin_suppliers_path,
           params: { address: fiscal_address(country_id: '') },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.fetch('errors').fetch('country_id')).to eq(['País no puede estar vacío'])
    end

    it 'uses the same rose typography as the other fiscal fields' do
      get new_admin_supplier_path

      page = Nokogiri::HTML(response.body)
      address_errors = page.css('[data-supplier-address-model-error]')
      expect(address_errors).not_to be_empty
      address_errors.each do |message|
        expect(message['class'].split).to include('mt-1', 'text-xs', 'text-rose-600')
        expect(message['class'].split).not_to include('font-semibold')
      end
    end
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

    expect(response).to have_http_status(:unauthorized)
  end
end

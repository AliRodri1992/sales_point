# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier Mexican postal suggestions', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  def lookup(supplier_id = supplier)
    get postal_code_suggestions_admin_supplier_path(supplier_id),
        params: { country: 'MX', postal_code: '54800' }
  end

  it 'returns municipality, state, and neighborhoods without exposing the provider URL' do
    data = { found: true, municipality: 'Cuautitlán',
             state: 'Estado de México', neighborhoods: %w[Centro Alameda] }
    allow_any_instance_of(Suppliers::MexicanPostalLookup).to receive(:call).and_return(data)

    lookup

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('municipality' => 'Cuautitlán')
    expect(response.parsed_body.fetch('neighborhoods')).to eq(%w[Centro Alameda])
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'returns an unavailable response so the form can keep manual input' do
    allow_any_instance_of(Suppliers::MexicanPostalLookup).to receive(:call).and_return(nil)

    lookup

    expect(response).to have_http_status(:service_unavailable)
  end

  it 'rejects incorrect and non-Mexican postal requests' do
    get postal_code_suggestions_admin_supplier_path(supplier),
        params: { country: 'US', postal_code: '54800' }
    expect(response).to have_http_status(:unprocessable_content)

    get postal_code_suggestions_admin_supplier_path(supplier),
        params: { country: 'MX', postal_code: '5480' }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'allows postal suggestions when creating a new supplier with permission' do
    data = { found: true, municipality: 'Cuautitlán',
             state: 'Estado de México', neighborhoods: ['Centro'] }
    allow_any_instance_of(Suppliers::MexicanPostalLookup).to receive(:call).and_return(data)

    get admin_supplier_postal_suggestions_path, params: { country: 'MX', postal_code: '54800' }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch('municipality')).to eq('Cuautitlán')
  end

  it 'denies postal suggestions for supplier creation without the create permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:create?).and_return(false)

    get admin_supplier_postal_suggestions_path, params: { country: 'MX', postal_code: '54800' }

    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects users lacking permission to manage supplier addresses' do
    allow_any_instance_of(SupplierPolicy).to receive(:manage_addresses?).and_return(false)

    lookup

    expect(response).to have_http_status(:forbidden)
  end

  it 'does not reveal another organization supplier postal data' do
    external = create(:supplier, organization: create(:organization))

    lookup(external)

    expect(response).to have_http_status(:not_found)
  end
  it 'renders the branded searchable neighborhood suggestion dropdown' do
    get new_admin_supplier_address_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-supplier-postal-assist-target="choicesWrapper"')
    expect(response.body).to include('data-supplier-postal-assist-target="choices"')
    expect(response.body).to include('data-searchable="true"')
    expect(response.body).to include('data-wrap-options="true"')
  end
  it 'keeps the Mapbox preview at the native 600 by 300 aspect ratio' do
    get new_admin_supplier_address_path(supplier)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    map = document.at_css('[data-supplier-address-location-target="mapPlaceholder"]').parent

    expect(map['class']).to include('aspect-[2/1]')
    expect(map['class']).not_to include('max-h-[640px]')
    expect(map.at_css('[data-supplier-address-location-target="mapImage"]')['class'])
      .to include('object-contain')
  end

  it 'supplies the UI with the same required-region country codes as the model' do
    get new_admin_supplier_address_path(supplier)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    fields = document.at_css('[data-controller*="supplier-country-fields"]')
    codes = JSON.parse(fields['data-supplier-country-fields-state-required-codes-value'])

    expect(codes).to match_array(Addresses::CountryRules::STATE_REQUIRED)
    expect(codes).to include('AR', 'CO', 'CL', 'PE', 'ZA')
  end

  it 'forbids postal suggestions without an active organization context' do
    allow_any_instance_of(Admin::SupplierPostalCodesController).to receive(:current_organization).and_return(nil)
    expect(Suppliers::MexicanPostalLookup).not_to receive(:new)

    lookup

    expect(response).to have_http_status(:forbidden)
  end

  it 'never invokes an external lookup for invalid postal input' do
    expect(Suppliers::MexicanPostalLookup).not_to receive(:new)

    get postal_code_suggestions_admin_supplier_path(supplier),
        params: { country: 'MX', postal_code: '54-800' }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects a postal code containing a newline without contacting the provider' do
    expect(Suppliers::MexicanPostalLookup).not_to receive(:new)

    get postal_code_suggestions_admin_supplier_path(supplier),
        params: { country: 'MX', postal_code: "54800\n" }

    expect(response).to have_http_status(:unprocessable_content)
  end
end

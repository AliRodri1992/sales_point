# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier fiscal address on the dossier', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: admin_role)
    sign_in user
  end

  def fiscal_address_panel
    Nokogiri::HTML(response.body).at_css('#supplier-dossier-fiscal [data-fiscal-address]')
  end

  it 'shows the registered primary fiscal address with each address field' do
    fiscal_attributes = {
      street: 'Calle Fiscal', exterior_number: '37', interior_number: '2B',
      neighborhood: 'Centro Fiscal', city: 'Ciudad Fiscal', state: 'Estado Fiscal',
      postal_code: '54800'
    }
    address = create(:address, :fiscal, :primary, addressable: supplier, **fiscal_attributes)
    create(:address, :delivery, addressable: supplier, street: 'Delivery Street')

    get admin_supplier_path(supplier, tab: 'fiscal')

    expect(response).to have_http_status(:ok)
    expect(fiscal_address_panel.text).to include(
      'Calle Fiscal 37', '2B', 'Centro Fiscal', 'Ciudad Fiscal',
      'Estado Fiscal', '54800', address.country.name
    )
    expect(fiscal_address_panel.text).not_to include('Delivery Street')
    expect(fiscal_address_panel.at_css('button[data-section="addresses"]')).to be_present
    expect(Nokogiri::HTML(response.body).at_css('#supplier-dossier-fiscal').text).not_to include('06000')
  end

  it 'shows an existing fiscal address even when it was not marked primary' do
    create(:address, :fiscal, addressable: supplier, primary: false, street: 'Fiscal Secundaria')

    get admin_supplier_path(supplier, tab: 'fiscal')

    expect(response).to have_http_status(:ok)
    expect(fiscal_address_panel.text).to include('Fiscal Secundaria')
    expect(fiscal_address_panel.text).not_to include('No fiscal address registered yet')
  end

  it 'prefers the primary fiscal address over other fiscal addresses' do
    create(:address, :fiscal, addressable: supplier, primary: false, street: 'Fiscal Antigua')
    create(:address, :fiscal, :primary, addressable: supplier, street: 'Fiscal Principal')

    get admin_supplier_path(supplier, tab: 'fiscal')

    expect(fiscal_address_panel.text).to include('Fiscal Principal')
    expect(fiscal_address_panel.text).not_to include('Fiscal Antigua')
  end

  it 'never shows a soft-deleted fiscal address' do
    create(:address, :fiscal, :primary, :deleted, addressable: supplier, street: 'Fiscal Eliminada')

    get admin_supplier_path(supplier, tab: 'fiscal')

    expect(fiscal_address_panel.text).to include('No fiscal address registered yet')
    expect(fiscal_address_panel.text).not_to include('Fiscal Eliminada')
  end

  it 'shows the missing-address state and preserves the supplier tax postal code' do
    get admin_supplier_path(supplier, tab: 'fiscal')

    expect(response).to have_http_status(:ok)
    expect(fiscal_address_panel.text).to include('No fiscal address registered yet')
    expect(Nokogiri::HTML(response.body).at_css('#supplier-dossier-fiscal').text).to include(supplier.postal_code)
  end

  it 'translates the fiscal-address section into Spanish and Korean' do
    { es: 'Dirección fiscal registrada', ko: '등록된 세금 주소' }.each do |locale, label|
      user.language = Language.find_by(code: locale.to_s) || create(:language, code: locale.to_s)
      user.save!
      get admin_supplier_path(supplier, tab: 'fiscal')

      expect(response).to have_http_status(:ok)
      expect(fiscal_address_panel.text).to include(label)
    end
  end
end

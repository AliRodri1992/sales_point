# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier address cards and progressive loading', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  def cards
    Nokogiri::HTML(response.body).css('article[data-supplier-address-id]')
  end

  def address_panel
    Nokogiri::HTML(response.body).at_css('#supplier-dossier-addresses')
  end

  it 'separates the header from two-column cards with expandable real address details' do
    attributes = {
      street: 'Calle Principal', exterior_number: '42',
      city: 'Guadalajara', postal_code: '44100'
    }
    address = create(:address, :fiscal, :primary, addressable: supplier, **attributes)
    get admin_supplier_path(supplier, tab: 'addresses')

    expect(response).to have_http_status(:ok)
    expect(address_panel['data-controller']).to eq('supplier-addresses')
    header = address_panel.at_css('[data-supplier-addresses-header]')
    card_area = address_panel.at_css('[data-supplier-addresses-cards]')
    expect(header.parent).to eq(address_panel)
    expect(card_area.parent).to eq(address_panel)
    expect(header.css('article[data-supplier-address-id]')).to be_empty

    list = card_area.at_css('[data-supplier-addresses-target="list"]')
    expect(list['class']).to include('md:grid-cols-2')
    expect(card_area.at_css('[data-supplier-addresses-target="scroll"]')['class']).to include('overflow-y-auto')
    card = list.at_css("article[data-supplier-address-id='#{address.id}']")
    expect(card).to be_present
    expect(card.text).to include('Calle Principal', '42', 'Guadalajara', '44100')
    expect(card.text).to include(address.country.localized_name)
    expect(card.at_css('button[aria-expanded="false"]')).to be_present
    expect(card.at_css("[id='supplier-address-detail-#{address.id}']")['class']).to include('hidden')
    expect(card.at_css("a[href='#{edit_admin_supplier_address_path(supplier, address)}']")).to be_present
  end

  it 'displays correct counters and places Manage addresses alongside the filters' do
    create(:address, :fiscal, :primary, addressable: supplier)
    2.times { |i| create(:address, :delivery, addressable: supplier, street: "Delivery Street #{i}") }
    create(:address, addressable: supplier, purpose: 'commercial')
    create(:address, addressable: supplier, purpose: 'general')

    get admin_supplier_path(supplier, tab: 'addresses')

    toolbar = address_panel.at_css('[data-supplier-addresses-toolbar]')
    buttons = toolbar.css('button[data-supplier-addresses-target="filter"]')
    expect(buttons.pluck('data-filter')).to eq(%w[all fiscal delivery commercial general primary])
    expect(buttons.map { |button| button.at_css('[data-supplier-addresses-target="filterCount"]').text })
      .to eq(%w[5 1 2 1 1 1])
    expect(buttons.map { |button| button.text.squish }).to eq(
      ['All 5', 'Tax 1', 'Delivery 2', 'Commercial 1', 'General 1', 'Primary 1']
    )
    expect(toolbar.at_css("a[href='#{admin_supplier_addresses_path(supplier)}']")).to be_present
    expect(toolbar.css("a[href='#{admin_supplier_addresses_path(supplier)}']").size).to eq(1)
  end

  it 'loads only eight cards initially and provides subsequent pages' do
    19.times { |i| create(:address, :delivery, addressable: supplier, street: "Delivery Street #{i}") }

    get admin_supplier_path(supplier, tab: 'addresses')

    expect(cards.size).to eq(8)
    expect(address_panel['data-supplier-addresses-next-page-value']).to eq('2')
    expect(address_panel.at_css('[data-supplier-addresses-target="count"]').text).to eq('19')

    get addresses_page_admin_supplier_path(supplier), params: { page: 2 }
    expect(response).to have_http_status(:ok)
    expect(cards.size).to eq(8)
    expect(response.headers['X-Next-Page']).to eq('3')
    expect(response.headers['X-Addresses-Count']).to eq('19')

    get addresses_page_admin_supplier_path(supplier), params: { page: 3 }
    expect(cards.size).to eq(3)
    expect(response.headers['X-Next-Page']).to eq('')
  end

  it 'returns filter counters independent of the selected category and matching the search' do
    create(:address, :fiscal, :primary, addressable: supplier, city: 'Monterrey')
    create(:address, :delivery, addressable: supplier, city: 'Monterrey')
    create(:address, :delivery, addressable: supplier, city: 'Guadalajara')

    get addresses_page_admin_supplier_path(supplier), params: { q: 'Monterrey', filter: 'delivery' }

    expect(response).to have_http_status(:ok)
    expect(cards.size).to eq(1)
    expect(response.headers['X-Addresses-Count']).to eq('1')
    expect(JSON.parse(response.headers['X-Addresses-Filter-Counts'])).to eq(
      'all' => 2, 'fiscal' => 1, 'delivery' => 1,
      'commercial' => 0, 'general' => 0, 'primary' => 1
    )
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'excludes deleted addresses and those of another supplier' do
    create(:address, :fiscal, :deleted, addressable: supplier, street: 'Deleted Road')
    other_supplier = create(:supplier, organization: create(:organization))
    create(:address, :delivery, addressable: other_supplier, street: 'Private Road')

    get addresses_page_admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(response.headers['X-Addresses-Count']).to eq('0')
    expect(response.body).not_to include('Private Road', 'Deleted Road')

    get addresses_page_admin_supplier_path(other_supplier)
    expect(response).to have_http_status(:not_found)
  end

  it 'protects the paginated endpoint with the address view permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:view_addresses?).and_return(false)

    get addresses_page_admin_supplier_path(supplier)

    expect(response).to have_http_status(:forbidden)
  end

  it 'does not expose Edit when address management is denied' do
    create(:address, :fiscal, addressable: supplier)
    allow_any_instance_of(SupplierPolicy).to receive(:manage_addresses?).and_return(false)

    get admin_supplier_path(supplier, tab: 'addresses')
    expect(cards.size).to eq(1)
    expect(cards.first.css('details')).to be_empty

    get addresses_page_admin_supplier_path(supplier)
    expect(cards.first.css('details')).to be_empty
  end

  it 'renders a dedicated empty state and zeros when there are no addresses' do
    get admin_supplier_path(supplier, tab: 'addresses')

    expect(cards).to be_empty
    expect(address_panel.at_css('[data-supplier-addresses-target="empty"]')['class']).not_to include('hidden')
    expect(address_panel.at_css('[data-supplier-addresses-target="loadMore"]')['class']).to include('hidden')
    expect(address_panel.css('[data-supplier-addresses-target="filterCount"]').map(&:text))
      .to eq(%w[0 0 0 0 0 0])
  end

  it 'shows localized type labels in Spanish and Korean' do
    create(:address, :fiscal, addressable: supplier)
    { es: 'Domicilio fiscal', ko: '세무 주소' }.each do |locale, label|
      user.language = Language.find_by(code: locale.to_s) || create(:language, code: locale.to_s)
      user.save!

      get admin_supplier_path(supplier, tab: 'addresses')

      expect(response).to have_http_status(:ok)
      expect(cards.first.text).to include(label)
    end
  end
end

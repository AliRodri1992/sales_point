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
    panel = address_panel
    expect(panel['data-controller']).to eq('supplier-addresses')
    header = panel.at_css('[data-supplier-addresses-header]')
    card_area = panel.at_css('[data-supplier-addresses-cards]')
    expect(header.parent).to eq(panel)
    expect(card_area.parent).to eq(panel)
    expect(header.css('article[data-supplier-address-id]')).to be_empty

    list = card_area.at_css('[data-supplier-addresses-target="list"]')
    expect(list['class']).to include('md:grid-cols-2')
    expect(card_area.at_css('[data-supplier-addresses-target="scroll"]')['class']).not_to include('overflow-y-auto')
    card = list.at_css("article[data-supplier-address-id='#{address.id}']")
    expect(card).to be_present
    expect(card.text).to include('Calle Principal', '42', 'Guadalajara', '44100')
    expect(card.text).to include(address.country.localized_name)
    expect(card.at_css('button[aria-expanded="false"]')).to be_present
    expect(card.at_css("[id='supplier-address-detail-#{address.id}']")['class']).to include('hidden')
    expect(card.css("a[href='#{edit_admin_supplier_address_path(supplier, address)}']")).to be_empty
    expect(card.css('details')).to be_empty
  end

  it 'shows the primary badge without repeating primary status in expanded details' do
    primary = create(:address, :fiscal, :primary, addressable: supplier)
    secondary = create(:address, :delivery, addressable: supplier)

    get admin_supplier_path(supplier, tab: 'addresses')

    primary_card = cards.find { |card| card['data-supplier-address-id'] == primary.id.to_s }
    secondary_card = cards.find { |card| card['data-supplier-address-id'] == secondary.id.to_s }

    expect(primary_card.text).to include('Primary')
    expect(primary_card.at_css('[data-address-detail]').css('dt').map(&:text)).not_to include('Primary')
    expect(primary_card.at_css('[data-address-detail]').text).not_to include('Yes')
    expect(secondary_card.at_css('[data-address-detail]').css('dt').map(&:text)).not_to include('Primary')
    expect(secondary_card.at_css('[data-address-detail]').text).not_to include('No')
  end

  it 'offers setting secondary addresses as primary without edit or delete in the dossier' do
    address = create(:address, :fiscal, addressable: supplier)

    get admin_supplier_path(supplier, tab: 'addresses')

    card = cards.first
    action_path = set_primary_admin_supplier_address_path(supplier, address, source: 'dossier')
    expect(card.at_css("form[action='#{action_path}']")).to be_present
    expect(card.css('a[href^="/admin"], form[action*="edit"], form[action*="destroy"]')).to be_empty
    expect(card.at_css('button[aria-expanded="false"]')).to be_present
    expect(address_panel.at_css('[data-supplier-addresses-target="list"]')['class']).to include('md:grid-cols-2')
  end

  it 'displays pending and approximate location states even without confirmed coordinates' do
    no_coords = create(:address, :fiscal, addressable: supplier, latitude: nil, longitude: nil)
    waiting = create(:address, :delivery, addressable: supplier, geocoding_status: 'pending')
    located = create(:address, addressable: supplier, purpose: 'commercial', geocoding_status: 'success')

    get admin_supplier_path(supplier, tab: 'addresses')

    expect(cards.find { |card| card['data-supplier-address-id'] == no_coords.id.to_s }
             .at_css('[data-address-geocoding-status]')['data-address-geocoding-status']).to eq('pending')
    expect(cards.find { |card| card['data-supplier-address-id'] == waiting.id.to_s }
             .at_css('[data-address-geocoding-status]')['data-address-geocoding-status']).to eq('pending')
    expect(cards.find { |card| card['data-supplier-address-id'] == located.id.to_s }
             .at_css('[data-address-geocoding-status]')['data-address-geocoding-status']).to eq('success')
  end

  it 'omits blank references from the expanded details' do
    create(:address, :fiscal, addressable: supplier, reference_notes: nil)

    get admin_supplier_path(supplier, tab: 'addresses')

    expect(cards.first.text).not_to include('Directions / landmarks')
  end

  it 'displays address references in the expanded details after the migration' do
    create(:address, :fiscal, addressable: supplier, reference_notes: 'Next to the municipal park')

    get admin_supplier_path(supplier, tab: 'addresses')

    expect(response).to have_http_status(:ok)
    expect(cards.first.text).to include('Next to the municipal park')
  end

  it 'keeps supplier details available if the references column has not been migrated locally' do
    create(:address, :fiscal, addressable: supplier)
    allow_any_instance_of(Address).to receive(:has_attribute?).and_call_original
    allow_any_instance_of(Address).to receive(:has_attribute?).with(:reference_notes).and_return(false)

    get admin_supplier_path(supplier, tab: 'addresses')

    expect(response).to have_http_status(:ok)
    expect(cards.size).to eq(1)
    expect(cards.first.text).to include('Av. Reforma')
    expect(cards.first.text).not_to include('Directions / landmarks')
  end

  it 'displays correct counters, with Manage addresses in the heading row and search below filters' do
    create(:address, :fiscal, :primary, addressable: supplier)
    2.times { |i| create(:address, :delivery, addressable: supplier, street: "Delivery Street #{i}") }
    create(:address, addressable: supplier, purpose: 'commercial')
    create(:address, addressable: supplier, purpose: 'general')

    get admin_supplier_path(supplier, tab: 'addresses')

    toolbar = address_panel.at_css('[data-supplier-addresses-toolbar]')
    buttons = toolbar.css('button[data-supplier-addresses-target="filter"]')
    expect(buttons.pluck('data-filter')).to eq(Suppliers::DossierAddressesPage::FILTERS)
    expect(buttons.first(6).map { |button| button.at_css('[data-supplier-addresses-target="filterCount"]').text })
      .to eq(%w[5 1 2 1 1 1])
    expect(buttons.first(6).map { |button| button.text.squish }).to eq(
      ['All 5', 'Tax 1', 'Delivery 2', 'Commercial 1', 'General 1', 'Primary 1']
    )
    title_row = address_panel.at_css('[data-supplier-addresses-title-row]')
    expect(title_row.at_css("a[href='#{admin_supplier_addresses_path(supplier)}']")).to be_present
    expect(toolbar.css("a[href='#{admin_supplier_addresses_path(supplier)}']")).to be_empty
    expect(toolbar.at_css('[data-supplier-addresses-filters]').next_element)
      .to eq(toolbar.at_css('[data-supplier-addresses-search-row]'))
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
      'commercial' => 0, 'general' => 0, 'primary' => 1,
      'confirmed' => 0, 'approximate' => 0, 'pending' => 2, 'failed' => 0
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
      .to eq(Array.new(Suppliers::DossierAddressesPage::FILTERS.length, '0'))
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

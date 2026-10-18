# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier address integration', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  def mexican_country
    Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX')
  end

  def address_attributes(overrides = {})
    { street: 'Main Street', exterior_number: '12', neighborhood: 'Centro',
      city: 'Mexico City', state: 'CDMX', country_id: mexican_country.id, postal_code: '06000',
      purpose: 'fiscal', primary: true }.merge(overrides)
  end

  it 'renders translated Mapbox location progress text instead of translation_missing' do
    get new_admin_supplier_address_path(supplier)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    form = page.at_css('form[data-controller~="supplier-address-location"]')
    expect(form).to be_present
    expect(form['data-supplier-address-location-searching-value']).to eq('Looking up the address location…')
    expect(response.body).not_to include('translation_missing')
  end

  it 'creates and displays a primary fiscal address' do
    post admin_supplier_addresses_path(supplier), params: { address: address_attributes }

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    address = supplier.addresses.last
    expect(address).to have_attributes(purpose: 'fiscal', primary: true)

    get admin_supplier_path(supplier, tab: 'addresses')
    expect(response.body).to include('Main Street')
  end

  it 'renders the supplier address editor as a single form with classification cards and a live preview' do
    get new_admin_supplier_address_path(supplier)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    form = page.at_css('form[data-controller~="supplier-address-preview"]')
    expect(form).to be_present
    expect(form.at_css('section[aria-labelledby="supplier-address-location-heading"]')).to be_present
    expect(form.at_css('section[aria-labelledby="supplier-address-classification-heading"]')).to be_present
    expect(form.at_css('section[aria-labelledby="supplier-address-preview-heading"]')).to be_present
    expect(form.css('input[name="address[purpose]"]').pluck('value')).to eq(
      %w[fiscal commercial delivery general]
    )
    expect(form.css('input[name="address[primary]"]').pluck('value')).to match_array(%w[false true])
    expect(form.at_css('textarea[name="address[reference_notes]"]')).to be_present
    expect(form.at_css('[data-supplier-address-preview-target="address"]')).to be_present
    expect(form.at_css('[data-supplier-address-preview-target="country"]')).to be_present
    expect(form.at_css('[data-supplier-address-preview-target="reference"]')).to be_present
    expect(form.at_css('p')).to be_present
    expect(form.at_css('button[type="submit"]')).to be_present
    expect(form.at_css("a[href='#{admin_supplier_addresses_path(supplier)}']")).to be_present
    expect(page.text).to include('SUP-', 'Add address')
    expect(page.css('[data-step]')).to be_empty
  end

  it 'adds optional Mexico postal lookup without blocking model validations or manual input' do
    mexican_country
    get new_admin_supplier_address_path(supplier)

    page = Nokogiri::HTML(response.body)
    location = page.at_css('[data-controller~="supplier-postal-assist"]')
    expect(location).to be_present
    expect(location['data-supplier-postal-assist-url-value'])
      .to eq(postal_code_suggestions_admin_supplier_path(supplier))
    expect(location.at_css('input[name="address[neighborhood]"][list="supplier-neighborhoods"]')).to be_present
    expect(location.at_css('datalist[data-supplier-postal-assist-target="neighborhoods"]')).to be_present
    expect(location.at_css('[data-supplier-postal-assist-target="status"]')).to be_present
    expect(page.at_css('form[data-controller~="supplier-address-preview"]')['novalidate']).not_to be_nil
    expect(location.at_css('select[name="address[country_id]"] option[data-country-code="MX"][data-flag-url]'))
      .to be_present
  end

  it 'provides the postal assistant inside the supplier fiscal address editor' do
    get new_admin_supplier_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    postal = page.at_css('[data-supplier-postal-assist-url-value]')
    expect(postal).to be_present
    expect(postal['data-supplier-postal-assist-url-value']).to eq(admin_supplier_postal_suggestions_path)
    expect(postal.at_css('[data-supplier-postal-field="postal_code"]')).to be_present
    expect(postal.at_css('[data-supplier-postal-field="country_id"]')).to be_present
    expect(postal.at_css('[data-supplier-postal-assist-target="neighborhoods"]')).to be_present
    expect(postal.at_css('[data-supplier-postal-assist-target="status"]')).to be_present
  end

  it 'places the preview above classification and aligns the right column with the address fields' do
    get new_admin_supplier_address_path(supplier)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    form = page.at_css('form[data-controller~="supplier-address-preview"]')
    columns = form.at_css('div.grid.items-stretch')
    expect(columns).to be_present

    right_column = form.at_css('[data-address-layout="right"]')
    expect(right_column['class']).to include('flex-col', 'lg:h-full')
    expect(right_column.element_children.pluck('aria-labelledby')).to eq(
      %w[supplier-address-preview-heading supplier-address-classification-heading]
    )
    expect(right_column.element_children.last['class']).to include('flex-1')
  end

  it 'preserves the same section ordering when editing an address' do
    address = create(:address, :fiscal, addressable: supplier)

    get edit_admin_supplier_address_path(supplier, address)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    sections = page.css('[data-address-layout="right"] > section')
    expect(sections.pluck('aria-labelledby')).to eq(
      %w[supplier-address-preview-heading supplier-address-classification-heading]
    )
    expect(sections.last['class']).to include('flex-1')
  end

  it 'uses the address model for validation instead of native browser restrictions' do
    get new_admin_supplier_address_path(supplier)

    page = Nokogiri::HTML(response.body)
    form = page.at_css('form[data-controller~="supplier-address-preview"]')
    expect(form['novalidate']).not_to be_nil

    browser_validations = %w[required pattern minlength maxlength]
    %w[country_id postal_code street exterior_number interior_number neighborhood state city].each do |field|
      input = form.at_css("[name='address[#{field}]']")
      expect(input).to be_present
      browser_validations.each do |attribute|
        expect(input[attribute]).to be_nil
      end
    end
    expect(form.at_css('textarea[name="address[reference_notes]"]')['maxlength']).to be_nil
    expect(form.css('input[name="address[purpose]"][required]')).to be_empty
  end

  it 'shows simultaneous model validation messages beneath each invalid address field' do
    invalid = address_attributes(
      country_id: mexican_country.id, street: '', exterior_number: '', neighborhood: '',
      city: '', state: '', postal_code: 'AB123', purpose: 'invalid'
    )
    post admin_supplier_addresses_path(supplier), params: { address: invalid }

    expect(response).to have_http_status(:unprocessable_content)
    page = Nokogiri::HTML(response.body)
    form = page.at_css('form[data-controller~="supplier-address-preview"]')
    expect(form['novalidate']).not_to be_nil

    %w[street exterior_number neighborhood city state postal_code purpose].each do |field|
      wrapper = form.at_css("[data-address-field='#{field}']")
      expect(wrapper).to be_present
      expect(wrapper.at_css('[data-server-field-error]')).to be_present
    end
    expect(form.at_css("[data-address-field='postal_code'] [data-server-field-error]").text)
      .to include('Postal code')
    expect(form.at_css("[data-address-field='street'] [data-server-field-error]").text)
      .to include('Street')
    expect(form.at_css("input[name='address[postal_code]']")['value']).to eq('AB123')
  end

  it 'preserves entered values and inline model messages after an invalid edit' do
    address = create(:address, :fiscal, addressable: supplier)
    invalid = address_attributes(
      country_id: address.country_id, street: 'X', city: '',
      postal_code: '1234', purpose: 'delivery', primary: false
    )
    patch admin_supplier_address_path(supplier, address), params: { address: invalid }

    expect(response).to have_http_status(:unprocessable_content)
    page = Nokogiri::HTML(response.body)
    %w[street city postal_code].each do |field|
      expect(page.at_css("[data-address-field='#{field}'] [data-server-field-error]")).to be_present
    end
    expect(page.at_css("input[name='address[street]']")['value']).to eq('X')
    expect(page.at_css("input[name='address[postal_code]']")['value']).to eq('1234')
  end

  it 'renders the address form without references while the database migration is pending' do
    allow_any_instance_of(Address).to receive(:has_attribute?).and_call_original
    allow_any_instance_of(Address).to receive(:has_attribute?).with(:reference_notes).and_return(false)

    get new_admin_supplier_address_path(supplier)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('form[data-controller~="supplier-address-preview"]')).to be_present
    expect(page.at_css('textarea[name="address[reference_notes]"]')).to be_nil
  end

  it 'persists optional address references and reuses the editor on update' do
    post admin_supplier_addresses_path(supplier),
         params: { address: address_attributes(reference_notes: 'White building near the market') }

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    address = supplier.addresses.last
    expect(address.reference_notes).to eq('White building near the market')

    get edit_admin_supplier_address_path(supplier, address)

    page = Nokogiri::HTML(response.body)
    expect(page.at_css('textarea[name="address[reference_notes]"]').text)
      .to include('White building near the market')
    expect(page.at_css('input[name="address[purpose]"][value="fiscal"]')['checked']).to be_present

    changes = address_attributes(reference_notes: 'Next to the pharmacy', country_id: address.country_id)
    patch admin_supplier_address_path(supplier, address), params: { address: changes }

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(address.reload.reference_notes).to eq('Next to the pharmacy')
  end

  it 'shows the length validation next to optional address references' do
    post admin_supplier_addresses_path(supplier),
         params: { address: address_attributes(reference_notes: 'X' * 201) }

    expect(response).to have_http_status(:unprocessable_content)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('textarea[name="address[reference_notes]"]').text).to include('XXX')
    expect(page.text).to include('is too long')
  end

  it 'retains invalid input and shows a field-specific postal code error' do
    post admin_supplier_addresses_path(supplier),
         params: { address: address_attributes(postal_code: 'ABC') }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('ABC', 'data-server-field-error')
  end

  it 'renders only eight active address cards and keeps accurate tab counts' do
    19.times { |i| create(:address, :delivery, addressable: supplier, street: "Warehouse #{i}") }
    3.times do |i|
      create(:address, :fiscal, addressable: supplier, street: "Archived #{i}", deleted_at: Time.current)
    end

    get admin_supplier_addresses_path(supplier)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.css('article[data-supplier-address-id]').size).to eq(8)
    expect(page.at_css('[data-supplier-addresses-next-page-value]')['data-supplier-addresses-next-page-value'])
      .to eq('2')
    tab_counts = page.at_css('[data-supplier-address-tabs]').css('a span').map { |element| element.text.strip }
    expect(tab_counts).to eq(%w[19 3])
    expect(page.at_css('[data-address-statistics]')).to be_present
    expect(page.css('[data-supplier-addresses-target="filterCount"]').map { |element| element.text.strip })
      .to eq(%w[19 0 19 0 0 0 0 0 19 0])
  end

  it 'paginates and filters active addresses in the administration search endpoint' do
    19.times { |i| create(:address, :delivery, addressable: supplier, street: "Delivery Lane #{i}") }
    create(:address, :fiscal, addressable: supplier, reference_notes: 'Beside BLUE gate')
    headers = { 'X-Requested-With' => 'XMLHttpRequest' }

    get admin_supplier_addresses_path(supplier), params: { page: 2 }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css('article[data-supplier-address-id]').size).to eq(8)
    expect(response.headers['X-Next-Page']).to eq('3')
    expect(response.headers['X-Addresses-Count']).to eq('20')
    expect(response.headers['Cache-Control']).to include('no-store')

    get admin_supplier_addresses_path(supplier), params: { q: 'blue', filter: 'fiscal' }, headers: headers

    expect(Nokogiri::HTML(response.body).css('article[data-supplier-address-id]').size).to eq(1)
    expect(response.headers['X-Addresses-Count']).to eq('1')
    expect(JSON.parse(response.headers['X-Addresses-Filter-Counts'])['fiscal']).to eq(1)
    expect(Nokogiri::HTML(response.body).css('[data-supplier-address-tabs]')).to be_empty
  end

  it 'searches and paginates deleted addresses without showing active records' do
    create(:address, :fiscal, addressable: supplier, street: 'Live Location')
    9.times do |i|
      attributes = { street: "Archived Lane #{i}", reference_notes: "Old gate #{i}", deleted_at: Time.current }
      create(:address, :delivery, addressable: supplier, **attributes)
    end

    get admin_supplier_addresses_path(supplier, status: 'deleted')
    page = Nokogiri::HTML(response.body)
    expect(page.css('article[data-supplier-address-id]').size).to eq(8)
    expect(page.css('form[action*="restore"]').size).to eq(8)
    expect(page.text).not_to include('Live Location')
    tab_counts = page.at_css('[data-supplier-address-tabs]').css('a span').map { |element| element.text.strip }
    expect(tab_counts).to eq(%w[1 9])

    get admin_supplier_addresses_path(supplier),
        params: { status: 'deleted', page: 2 }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }
    expect(Nokogiri::HTML(response.body).css('article[data-supplier-address-id]').size).to eq(1)

    get admin_supplier_addresses_path(supplier),
        params: { status: 'deleted', q: 'old gate 7', filter: 'delivery' },
        headers: { 'X-Requested-With' => 'XMLHttpRequest' }
    expect(Nokogiri::HTML(response.body).css('article[data-supplier-address-id]').size).to eq(1)
    expect(response.headers['X-Addresses-Count']).to eq('1')
  end

  it 'keeps edit and delete actions in administration and exposes primary selection only when needed' do
    primary = create(:address, :fiscal, :primary, addressable: supplier)
    secondary = create(:address, :fiscal, addressable: supplier)

    get admin_supplier_addresses_path(supplier)

    page = Nokogiri::HTML(response.body)
    primary_card = page.at_css("article[data-supplier-address-id='#{primary.id}']")
    secondary_card = page.at_css("article[data-supplier-address-id='#{secondary.id}']")
    expect(primary_card.css('form[action*="set_primary"]')).to be_empty
    expect(secondary_card.at_css("form[action='#{set_primary_admin_supplier_address_path(supplier, secondary)}']"))
      .to be_present
    expect(secondary_card.at_css("a[href='#{edit_admin_supplier_address_path(supplier, secondary)}']"))
      .to be_present
    expect(secondary_card.at_css("form[action='#{admin_supplier_address_path(supplier, secondary)}']"))
      .to be_present
  end

  it 'switches primary addresses transactionally from administration' do
    previous = create(:address, :fiscal, :primary, addressable: supplier)
    target = create(:address, :fiscal, addressable: supplier)
    delivery = create(:address, :delivery, :primary, addressable: supplier)

    patch set_primary_admin_supplier_address_path(supplier, target)

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(target.reload).to be_primary
    expect(previous.reload).not_to be_primary
    expect(delivery.reload).to be_primary
  end

  it 'returns to the supplier dossier after a primary switch from its address cards' do
    target = create(:address, :fiscal, addressable: supplier)

    patch set_primary_admin_supplier_address_path(supplier, target, source: 'dossier')

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'addresses'))
    expect(target.reload).to be_primary
  end

  it 'rejects the primary action when management permission is denied' do
    target = create(:address, :fiscal, addressable: supplier)
    allow_any_instance_of(SupplierPolicy).to receive(:manage_addresses?).and_return(false)

    patch set_primary_admin_supplier_address_path(supplier, target)

    expect(response).to have_http_status(:forbidden)
    expect(target.reload).not_to be_primary
  end

  it 'never changes an address belonging to a different supplier' do
    external = create(:address, :fiscal, addressable: create(:supplier))

    patch set_primary_admin_supplier_address_path(supplier, external)

    expect(response).to have_http_status(:not_found)
    expect(external.reload).not_to be_primary
  end

  it 'shows geocoding and references only when real location data exists' do
    create(:address, :delivery, addressable: supplier, latitude: nil, longitude: nil)
    attributes = { reference_notes: 'Blue gate', geocoding_status: :success }
    located = create(:address, :fiscal, addressable: supplier, **attributes)

    get admin_supplier_addresses_path(supplier)

    page = Nokogiri::HTML(response.body)
    expect(page.css('[data-address-geocoding-status]').size).to eq(2)
    expect(page.at_css('[data-address-geocoding-status]')['data-address-geocoding-status']).to eq('success')
    expect(page.at_css("article[data-supplier-address-id='#{located.id}']").text).to include('Blue gate')
    expect(page.css('article h2').map(&:text)).not_to include('##')
  end

  it 'hides administration actions without management permission' do
    create(:address, :fiscal, addressable: supplier)
    allow_any_instance_of(SupplierPolicy).to receive(:manage_addresses?).and_return(false)

    get admin_supplier_addresses_path(supplier)

    page = Nokogiri::HTML(response.body)
    expect(page.css('article[data-supplier-address-id] form, article[data-supplier-address-id] a')).to be_empty

    get admin_supplier_addresses_path(supplier), headers: { 'X-Requested-With' => 'XMLHttpRequest' }
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css('article form, article a')).to be_empty
  end

  it 'uses the existing illustration without a duplicate create action for an empty list' do
    get admin_supplier_addresses_path(supplier)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    empty = page.at_css('[data-address-empty="active"]')
    expect(empty.at_css('img[src*="saddresses"]')).to be_present
    expect(empty.text).to include('No addresses registered yet')
    expect(empty.css('a, button')).to be_empty
    expect(page.at_css('[data-address-statistics]')).to be_nil
    expect(page.css("a[href='#{new_admin_supplier_address_path(supplier)}']").size).to eq(1)

    tabs = page.at_css('[data-supplier-address-tabs]')
    expect(tabs.css('a span').map { |item| item.text.strip }).to eq(%w[0 0])
  end

  it 'shows a deleted-address empty state without duplicate buttons' do
    get admin_supplier_addresses_path(supplier, status: 'deleted')

    page = Nokogiri::HTML(response.body)
    empty = page.at_css('[data-address-empty="deleted"]')
    expect(empty.at_css('img[src*="saddresses"]')).to be_present
    expect(empty.text).to include('No deleted addresses')
    expect(empty.css('a, button')).to be_empty
    expect(page.at_css('[data-address-statistics]')).to be_nil
    expect(page.css("a[href='#{new_admin_supplier_address_path(supplier)}']").size).to eq(1)
  end

  it 'preserves the normal address cards and counters when records exist' do
    create(:address, :fiscal, :primary, addressable: supplier)

    get admin_supplier_addresses_path(supplier)

    page = Nokogiri::HTML(response.body)
    expect(page.at_css('[data-address-empty="active"]')['class']).to include('hidden')
    expect(page.at_css('[data-address-statistics]')).to be_present
    expect(page.css('article').size).to eq(1)
    expect(page.css("a[href='#{new_admin_supplier_address_path(supplier)}']").size).to eq(1)
  end

  it 'shows the empty active state when only archived addresses remain' do
    address = create(:address, :fiscal, :primary, addressable: supplier)
    address.update!(deleted_at: Time.current)

    get admin_supplier_addresses_path(supplier)

    page = Nokogiri::HTML(response.body)
    expect(page.at_css('[data-address-empty="active"]')).to be_present
    expect(page.at_css('[data-address-statistics]')).to be_present
    expect(page.at_css('[data-supplier-address-tabs]').css('a span').map { |item| item.text.strip }).to eq(%w[0 1])

    get admin_supplier_addresses_path(supplier, status: 'deleted')

    page = Nokogiri::HTML(response.body)
    expect(page.at_css('[data-address-empty="deleted"]')['class']).to include('hidden')
    expect(page.text).to include(address.street)
  end

  it 'does not show the create action to users without address management permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:manage_addresses?).and_return(false)

    get admin_supplier_addresses_path(supplier)

    page = Nokogiri::HTML(response.body)
    expect(page.at_css('[data-address-empty="active"]')).to be_present
    expect(page.at_css("a[href='#{new_admin_supplier_address_path(supplier)}']")).to be_nil
  end
  it 'atomically replaces the primary fiscal address from the edit form' do
    previous = create(:address, :fiscal, :primary, addressable: supplier)
    target = create(:address, :fiscal, addressable: supplier)

    patch admin_supplier_address_path(supplier, target),
          params: { address: address_attributes(primary: true) }

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(previous.reload).not_to be_primary
    expect(target.reload).to be_primary
  end

  it 'shows a failed location even when coordinates are absent and allows retry' do
    address = create(:address, :delivery, addressable: supplier,
                     geocoding_status: 'failed', latitude: nil, longitude: nil)
    get admin_supplier_addresses_path(supplier)
    expect(response.body).to include('data-address-geocoding-status="failed"')

    allow(GeocodeAddressJob).to receive(:perform_later)
    post retry_geocoding_admin_supplier_address_path(supplier, address)

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(address.reload.geocoding_status).to eq('pending')
    expect(GeocodeAddressJob).to have_received(:perform_later)
  end

end

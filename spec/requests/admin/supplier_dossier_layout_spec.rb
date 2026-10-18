# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier dossier navigation and overview', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:, name: 'Verifiable Supplier') }
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: admin_role)
    sign_in user
  end

  def dossier
    Nokogiri::HTML(response.body)
  end

  it 'renders the illustrated document empty state with an upload entry point' do
    get admin_supplier_path(supplier, tab: 'documents')

    panel = dossier.at_css('section[data-section="documents"]')
    expect(panel.at_css('img[src*="sdocuments"]')).to be_present
    expect(panel.text).to include('No documents registered yet')
    expect(panel.at_css("a[href='#{edit_admin_supplier_path(supplier)}']")).to be_present
  end

  it 'hides the document empty state when attachments exist' do
    supplier.documents.attach(
      io: StringIO.new('%PDF-1.4 test document'),
      filename: 'invoice.pdf',
      content_type: 'application/pdf'
    )

    get admin_supplier_path(supplier, tab: 'documents')

    panel = dossier.at_css('section[data-section="documents"]')
    expect(panel.text).to include('invoice.pdf')
    expect(panel.at_css('img[src*="sdocuments"]')).to be_nil
  end

  it 'does not offer document upload without document management permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:manage_documents?).and_return(false)

    get admin_supplier_path(supplier, tab: 'documents')

    panel = dossier.at_css('section[data-section="documents"]')
    expect(panel.at_css('img[src*="sdocuments"]')).to be_present
    expect(panel.at_css("a[href='#{edit_admin_supplier_path(supplier)}']")).to be_nil
  end

  it 'separates the calendar empty state from its management header' do
    get admin_supplier_path(supplier, tab: 'schedules')

    panel = dossier.at_css('section[data-section="schedules"]')
    header = panel.at_xpath('./div[1]')
    empty_state = panel.at_css('img[src*="scalendaries"]').parent

    expect(header.text).to include('Manage calendars')
    expect(header.at_css("a[href='#{admin_supplier_schedules_path(supplier)}']")).to be_present
    expect(header.text).not_to include('No calendars registered yet')
    expect(empty_state.text).to include('No calendars registered yet')
    expect(panel.css("a[href='#{admin_supplier_schedules_path(supplier)}']").size).to eq(1)
  end

  it 'shows a compact fiscal address empty state without an add button' do
    get admin_supplier_path(supplier, tab: 'fiscal')

    section = dossier.at_css('[data-fiscal-address]')
    expect(section.at_css('img[src*="staxaddress"]')).to be_present
    expect(section.text).to include('No fiscal address registered yet')
    expect(section.css('a, button').map(&:text).join).not_to include('Add fiscal address')
  end

  it 'shows registered fiscal address fields instead of the empty illustration' do
    supplier.addresses.create!(
      street: 'Main Street', exterior_number: '10', neighborhood: 'Centro',
      city: 'CDMX', state: 'CDMX', postal_code: '06000',
      country: create(:country), purpose: 'fiscal'
    )

    get admin_supplier_path(supplier, tab: 'fiscal')

    section = dossier.at_css('[data-fiscal-address]')
    expect(section.text).to include('Main Street')
    expect(section.at_css('img[src*="staxaddress"]')).to be_nil
  end

  it 'keeps supplier address summary aligned with the left card edge' do
    supplier.addresses.create!(
      street: 'Main Street', exterior_number: '23', neighborhood: 'Centro',
      city: 'Ixtepec', state: 'Oaxaca', postal_code: '70111',
      country: create(:country), purpose: 'delivery'
    )

    get admin_supplier_path(supplier, tab: 'addresses')

    card = dossier.at_css('[data-supplier-address-id]')
    summary = card.css('div').find { |node| node['class']&.include?('mt-4 flex items-start gap-2') }
    expect(summary).to be_present
    expect(summary['class']).not_to include('pl-14')
    expect(summary.text).to include('Main Street 23', 'Ixtepec', 'Oaxaca')
  end

  it 'renders the empty products illustration and actions for administrators' do
    get admin_supplier_path(supplier, tab: 'products')

    panel = dossier.at_css('section[data-section="products"]')
    expect(panel.at_css('img[src*="sproducts"]')).to be_present
    expect(panel.text).to include('No products registered yet')
    expect(panel.at_css("a[href='#{admin_supplier_supplier_products_path(supplier)}']")).to be_present
    expect(panel.at_css("a[href='#{new_admin_supplier_supplier_product_path(supplier)}']")).to be_present
  end

  it 'separates the products header from the empty content area' do
    get admin_supplier_path(supplier, tab: 'products')

    header = products_panel.at_css('[data-supplier-products-header]')
    content = products_panel.at_css('[data-supplier-products-content]')
    expect(products_panel['class']).to include('space-y-4')
    expect(header.parent).to eq(products_panel)
    expect(content.parent).to eq(products_panel)
    expect(header.text).to include('Supplier products')
    expect(header.text).to include('View the products associated with this supplier.')
    expect(header.at_css("a[href='#{admin_supplier_supplier_products_path(supplier)}']")).to be_present
    expect(header.at_css('img[src*="sproducts"]')).to be_nil
    expect(content.at_css('[data-supplier-products-empty] img[src*="sproducts"]')).to be_present
    expect(content.text).not_to include('Manage products')
  end

  it 'keeps the products header separate when supplier products are registered' do
    create_offer(create(:product, organization:, name: 'Sample Product'))

    get admin_supplier_path(supplier, tab: 'products')

    header = products_panel.at_css('[data-supplier-products-header]')
    content = products_panel.at_css('[data-supplier-products-content]')
    expect(header.parent).to eq(content.parent)
    expect(header.at_css('[data-supplier-product-card]')).to be_nil
    expect(content.css('[data-supplier-product-card]').length).to eq(1)
    expect(content.at_css('[data-supplier-products-pagination]')).to be_present
    expect(content.at_css('[data-supplier-products-empty]')).to be_nil
  end

  it 'does not show product creation without management permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:manage_products?).and_return(false)

    get admin_supplier_path(supplier, tab: 'products')

    panel = dossier.at_css('section[data-section="products"]')
    expect(panel.at_css('img[src*="sproducts"]')).to be_present
    expect(panel.at_css("a[href='#{new_admin_supplier_supplier_product_path(supplier)}']")).to be_nil
  end

  def create_offer(item, attributes = {})
    SupplierProduct.create!({
      organization:, supplier:, product: item, currency: supplier.currency,
      presentation_name: 'Box', units_per_package: 12, purchase_price: 144,
      minimum_quantity: 1, discount_percent: 0, freight_amount: 0,
      nonrecoverable_tax: 0, lead_time_days: 3
    }.merge(attributes))
  end

  def products_panel
    dossier.at_css('section[data-section="products"]')
  end

  it 'shows four product preview cards with image fallback, prices and preferred indicators' do
    pictured = create(:product, organization:, name: 'A Pictured Item', sku: 'PIC-01')
    png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLynwAAAABJRU5ErkJggg=='
    pictured.image.attach(io: StringIO.new(Base64.decode64(png)), filename: 'photo.png', content_type: 'image/png')
    create_offer(pictured, supplier_sku: 'SUP-PIC', preferred: true)
    create_offer(create(:product, organization:, name: 'Fallback Item'), supplier_sku: 'SUP-FALL')
    3.times do |index|
      create_offer(create(:product, organization:, name: "More Item #{index}"))
    end

    get admin_supplier_path(supplier, tab: 'products')

    expect(response).to have_http_status(:ok)
    cards = products_panel.css('[data-supplier-product-card]')
    expect(cards.length).to eq(4)
    photo_card = cards.find { |card| card.text.include?('Pictured Item') }
    fallback_card = cards.find { |card| card.text.include?('Fallback Item') }
    expect(photo_card.at_css('img')['src']).to include('active_storage')
    expect(fallback_card.at_css('img')['src']).to include('supplier-product-placeholder')
    expect(photo_card.text).to include('PIC-01', 'SUP-PIC', 'Preferred', '144', '12', supplier.currency.code)
    expect(products_panel.text).to include('Showing 1–4 of 5 products')
    expect(products_panel.css('[data-supplier-products-grid]')).to be_present
    expect(products_panel.css("a[href='#{admin_supplier_supplier_products_path(supplier)}']").size).to eq(1)
    expect(products_panel.css('details, form')).to be_empty
  end

  it 'paginates four products and keeps Products selected on the next page' do
    9.times do |number|
      create_offer(create(:product, organization:, name: format('Sorted Product %02d', number)))
    end

    get admin_supplier_path(supplier, tab: 'products', products_page: 2)

    expect(dossier.at_css('[data-controller="supplier-dossier"]')['data-supplier-dossier-initial-tab-value'])
      .to eq('products')
    expect(products_panel.css('[data-supplier-product-card]').size).to eq(4)
    expect(products_panel.text).to include('Showing 5–8 of 9 products')
    expect(products_panel.text).to include('Sorted Product 04')
    expect(products_panel.text).not_to include('Sorted Product 00', 'Sorted Product 08')
    expect(products_panel.at_css('a[aria-current="page"]').text.strip).to eq('2')
    expect(products_panel.at_css("a[href='#{admin_supplier_path(supplier, tab: 'products', products_page: 3)}']"))
      .to be_present

    get admin_supplier_path(supplier, tab: 'products', products_page: 3)

    expect(products_panel.css('[data-supplier-product-card]').size).to eq(1)
    expect(products_panel.text).to include('Showing 9–9 of 9 products')
  end

  it 'never displays unavailable, archived or other suppliers products' do
    create_offer(create(:product, organization:, name: 'Current Product'))
    create_offer(create(:product, organization:, name: 'Inactive Offer'), active: false)
    create_offer(create(:product, organization:, name: 'Archived Offer'), deleted_at: Time.current)
    create_offer(create(:product, organization:, name: 'Archived Product', deleted_at: Time.current))
    other_supplier = create(:supplier, organization:)
    SupplierProduct.create!(
      organization:, supplier: other_supplier,
      product: create(:product, organization:, name: 'Other Supplier Item'),
      currency: supplier.currency, presentation_name: 'Box', units_per_package: 4,
      purchase_price: 120, minimum_quantity: 1, discount_percent: 0,
      freight_amount: 0, nonrecoverable_tax: 0, lead_time_days: 2
    )

    get admin_supplier_path(supplier, tab: 'products')

    expect(products_panel.css('[data-supplier-product-card]').size).to eq(1)
    expect(products_panel.text).to include('Current Product')
    expect(products_panel.text).not_to include(
      'Inactive Offer', 'Archived Offer', 'Archived Product', 'Other Supplier Item'
    )
  end

  it 'omits product panel and cards when the user cannot view supplier products' do
    create_offer(create(:product, organization:, name: 'Restricted Product'))
    allow_any_instance_of(SupplierPolicy).to receive(:view_products?).and_return(false)

    get admin_supplier_path(supplier, tab: 'products')

    expect(response).to have_http_status(:ok)
    expect(products_panel).to be_nil
    expect(dossier.text).not_to include('Restricted Product')
    expect(dossier.css('button[data-section="products"]')).to be_empty
    expect(dossier.at_css('[data-controller="supplier-dossier"]')['data-supplier-dossier-initial-tab-value'])
      .to eq('overview')
  end

  it 'shows the new responsive navigation with only existing supplier features' do
    get admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(dossier.css('button[data-supplier-dossier-target="tab"]').pluck('data-section')).to eq(
      %w[overview general fiscal commercial contacts addresses schedules documents products bank_accounts statement]
    )
    expect(dossier.at_css('select[data-supplier-dossier-target="mobileSelect"]')).to be_present
    expect(dossier.at_css('#supplier-dossier-overview')).to be_present
    expect(dossier.at_css('#supplier-dossier-overview')['class']).not_to include('hidden')
    expect(dossier.at_css('#supplier-dossier-fiscal')['class']).to include('hidden')
    expect(response.body).not_to include('data-section="reconciliation"')
  end

  it 'groups both financial entries under Finance on desktop and mobile' do
    get admin_supplier_path(supplier)

    navigation = dossier.at_css('aside[aria-label]')
    finance_group = navigation.css('nav > div').find do |group|
      group.at_css('h2')&.text&.strip == I18n.t('admin.supplier_dossier.navigation.finances', locale: :en)
    end
    expect(finance_group).to be_present
    expect(finance_group.css('button[data-section]').pluck('data-section')).to eq(
      %w[bank_accounts statement]
    )

    mobile_finance = navigation.css('select optgroup').find do |group|
      group['label'] == I18n.t('admin.supplier_dossier.navigation.finances', locale: :en)
    end
    expect(mobile_finance).to be_present
    expect(mobile_finance.css('option').pluck('value')).to eq(%w[bank_accounts statement])
  end

  it 'places Back outside the three-dot menu and Edit inside it' do
    get admin_supplier_path(supplier)

    header = dossier.at_css('[data-controller="supplier-dossier"] > header')
    back_link = header.at_css("a[href='#{admin_suppliers_path}']")
    edit_link = header.at_css("details a[href='#{edit_admin_supplier_path(supplier)}']")

    expect(back_link).to be_present
    expect(back_link.text).to include('Back')
    expect(back_link.ancestors('details')).to be_empty
    expect(edit_link).to be_present
    expect(edit_link.text).to include('Edit')
    expect(header.css("a[href='#{edit_admin_supplier_path(supplier)}']").size).to eq(1)
    expect(header.at_css('details summary[aria-label]')).to be_present
  end

  it 'keeps Back available and hides the edit menu without update permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:update?).and_return(false)

    get admin_supplier_path(supplier)

    header = dossier.at_css('[data-controller="supplier-dossier"] > header')
    expect(header.at_css("a[href='#{admin_suppliers_path}']")).to be_present
    expect(header.at_css('details')).to be_nil
    expect(header.at_css("a[href='#{edit_admin_supplier_path(supplier)}']")).to be_nil
  end

  it 'uses the entire right-side area for every supplier section' do
    get admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    layout = dossier.at_css('[data-supplier-dossier-content]')
    expect(layout).to be_present
    expect(layout['class']).to include('w-full', 'flex-col')
    expect(dossier.at_css('[data-supplier-dossier-content]').parent['class'])
      .to include('lg:grid', 'lg:items-stretch')

    sections = %w[
      overview general fiscal commercial contacts addresses schedules documents bank_accounts products statement
    ]
    expect(layout.css('[data-supplier-dossier-target="panel"]').pluck('data-section')).to match_array(sections)
    layout.css('[data-supplier-dossier-target="panel"]').each do |panel|
      expect(panel['class']).to include('w-full', 'min-w-0', 'lg:flex-1')
    end
  end

  it 'highlights the full width of the selected menu item, not only its label' do
    get admin_supplier_path(supplier)

    sidebar = dossier.at_css('aside[aria-label] nav')
    expect(sidebar['class']).to include('lg:-mx-3')
    sidebar.css('button[data-supplier-dossier-target="tab"]').each do |tab|
      expect(tab['class']).to include('w-full', 'lg:px-6')
    end
  end

  it 'separates general company information from fiscal details' do
    get admin_supplier_path(supplier)

    general = dossier.at_css('#supplier-dossier-general')
    fiscal = dossier.at_css('#supplier-dossier-fiscal')
    expect(general.text).to include('Legal name', 'Trade name')
    expect(general.text).not_to include('Tax regime')
    expect(fiscal.text).to include('RFC', 'Tax regime', supplier.rfc)
    expect(fiscal.text).not_to include('Credit limit')
  end

  it 'shows actual registered contact counts in the overview' do
    create(:contact, contactable: supplier, name: 'Operations Contact', primary: true)

    get admin_supplier_path(supplier)

    summary = dossier.at_css('#supplier-dossier-overview')
    expect(summary.text).to include('Operations Contact')
    expect(summary.text).to include('Registered contacts')
  end

  it 'allows direct links to fiscal or contacts sections' do
    get admin_supplier_path(supplier, tab: 'fiscal')
    expect(dossier.at_css('[data-controller="supplier-dossier"]')['data-supplier-dossier-initial-tab-value'])
      .to eq('fiscal')

    get admin_supplier_path(supplier, tab: 'contacts')
    expect(dossier.at_css('[data-controller="supplier-dossier"]')['data-supplier-dossier-initial-tab-value'])
      .to eq('contacts')
  end

  it 'falls back to the overview for unknown sections' do
    get admin_supplier_path(supplier, tab: 'reconciliation')
    expect(dossier.at_css('[data-controller="supplier-dossier"]')['data-supplier-dossier-initial-tab-value'])
      .to eq('overview')
  end

  it 'preserves the supplier edit and all existing management links' do
    get admin_supplier_path(supplier)

    expect(response.body).to include(edit_admin_supplier_path(supplier))
    expect(response.body).to include(admin_supplier_contacts_path(supplier))
    expect(response.body).to include(admin_supplier_addresses_path(supplier))
    expect(response.body).to include(admin_supplier_schedules_path(supplier))
    expect(response.body).to include(admin_supplier_supplier_products_path(supplier))
  end
end

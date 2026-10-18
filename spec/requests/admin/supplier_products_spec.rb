# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin supplier procurement', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def valid_offer
    {
      product_id: product.id, currency_id: supplier.currency.id,
      presentation_name: 'Case', units_per_package: 12, purchase_price: 120,
      minimum_quantity: 1, discount_percent: 0, freight_amount: 0,
      nonrecoverable_tax: 0, lead_time_days: 3
    }
  end

  it 'creates a product offer scoped to the current organization' do
    post admin_supplier_supplier_products_path(supplier), params: { supplier_product: valid_offer }

    expect(response).to redirect_to(admin_supplier_supplier_products_path(supplier))
    expect(SupplierProduct.last).to have_attributes(organization_id: organization.id, product_id: product.id)
  end

  it 'rejects products owned by another organization' do
    foreign_product = create(:product, organization: create(:organization))
    post admin_supplier_supplier_products_path(supplier),
         params: { supplier_product: valid_offer.merge(product_id: foreign_product.id) }

    expect(response).to have_http_status(:not_found)
    expect(SupplierProduct.count).to eq(0)
  end

  it 'rejects foreign supplier access' do
    foreign_supplier = create(:supplier, organization: create(:organization))
    get admin_supplier_supplier_products_path(foreign_supplier)

    expect(response).to have_http_status(:not_found)
  end

  it 'shows the cost comparison for products in this organization' do
    SupplierProduct.create!(valid_offer.except(:product_id, :currency_id).merge(
                              organization:, supplier:, product:, currency: supplier.currency
                            ))
    get admin_supplier_product_comparison_path(supplier, product_id: product.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(product.name)
  end
  def offer_for(item, overrides = {})
    SupplierProduct.create!({
      organization:, supplier:, product: item, currency: supplier.currency,
      presentation_name: 'Case', units_per_package: 12, purchase_price: 120,
      minimum_quantity: 1, discount_percent: 0, freight_amount: 0,
      nonrecoverable_tax: 0, lead_time_days: 3
    }.merge(overrides))
  end

  def document
    Nokogiri::HTML(response.body)
  end

  it 'renders the product image or the emerald SVG placeholder, with SKU and costs' do
    with_image = create(:product, organization:, name: 'Photo Product', code: 'PHOTO-001')
    png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLynwAAAABJRU5ErkJggg=='
    image_data = Base64.decode64(png)
    with_image.image.attach(io: StringIO.new(image_data), filename: 'supplier-photo.png', content_type: 'image/png')
    offer_for(with_image, supplier_sku: 'PHOTO-SKU', preferred: true)
    no_image = create(:product, organization:, name: 'Without Photo', code: 'NO-PHOTO')
    offer_for(no_image)

    get admin_supplier_supplier_products_path(supplier)

    expect(response).to have_http_status(:ok)
    rows = document.css('[data-product-offer-row]')
    expect(rows.size).to eq(2)
    expect(rows.find { |row| row.text.include?('Photo Product') }.at_css('img')['src'])
      .to include('active_storage')
    expect(rows.find { |row| row.text.include?('Without Photo') }.at_css('img')['src'])
      .to include('supplier-product-placeholder')
    expect(document.text).to include('PHOTO-SKU', 'NO-PHOTO', 'Yes, preferred')
    expect(document.text).to include('120', '10')
  end

  it 'returns to the supplier Products tab and shows Back to the left of Add' do
    get admin_supplier_supplier_products_path(supplier)

    header = document.at_css('[data-supplier-products-header]')
    links = header.css('a')
    expected_paths = [
      admin_supplier_path(supplier, tab: 'products'),
      new_admin_supplier_supplier_product_path(supplier)
    ]
    expect(links.pluck('href')).to eq(expected_paths)
    expect(links.map { |link| link.text.strip }).to eq(%w[Back Add])

    get links.first['href']
    dossier = document.at_css('[data-controller="supplier-dossier"]')
    expect(dossier['data-supplier-dossier-initial-tab-value']).to eq('products')
  end

  it 'keeps every offer action in a three-dot menu' do
    offer = offer_for(product)

    get admin_supplier_supplier_products_path(supplier)

    menu = document.at_css('[data-product-offer-row] details')
    expect(menu.at_css('summary[aria-label="Actions"]')).to be_present
    expect(menu.at_css("a[href='#{history_admin_supplier_supplier_product_path(supplier, offer)}']"))
      .to be_present
    expect(menu.at_css("a[href='#{admin_supplier_product_comparison_path(supplier, product_id: product.id)}']"))
      .to be_present
    expect(menu.at_css("a[href='#{edit_admin_supplier_supplier_product_path(supplier, offer)}']"))
      .to be_present
    expect(menu.at_css("form[action='#{admin_supplier_supplier_product_path(supplier, offer)}']"))
      .to be_present
  end

  it 'filters by product name, catalog code, and supplier SKU' do
    item = create(:product, organization:, name: 'Almond Milk', code: 'MILK-888')
    offer_for(item, supplier_sku: 'SUP-MILK')
    offer_for(create(:product, organization:, name: 'Brown Rice', code: 'RICE-999'))

    %w[almond MILK-888 SUP-MILK].each do |query|
      get admin_supplier_supplier_products_path(supplier, q: query)
      expect(document.css('[data-product-offer-row]').length).to eq(1)
      expect(document.text).to include('Almond Milk')
      expect(document.text).not_to include('Brown Rice')
    end
  end

  it 'paginates six products without losing the search term' do
    8.times do |index|
      item = create(:product, organization:, name: format('Case Product %02d', index))
      offer_for(item)
    end

    get admin_supplier_supplier_products_path(supplier, q: 'Case Product')
    expect(document.css('[data-product-offer-row]').length).to eq(6)
    expect(document.text).to include('Showing 1–6 of 8 products')
    next_link = document.at_css('a[aria-label="Next page"]')
    expect(next_link['href']).to include('page=2', 'q=Case')

    get next_link['href']
    expect(document.css('[data-product-offer-row]').length).to eq(2)
    expect(document.text).to include('Showing 7–8 of 8 products')
  end

  it 'shows separate no-products and no-search-results states' do
    get admin_supplier_supplier_products_path(supplier)
    expect(document.at_css('[data-product-offers-empty] img[src*="sproducts"]')).to be_present

    offer_for(product)
    get admin_supplier_supplier_products_path(supplier, q: 'does-not-exist')
    expect(document.at_css('[data-product-search-empty]')).to be_present
    expect(document.at_css('[data-product-offers-empty]')).to be_nil
  end

  it 'does not show creation, editing, or deletion actions without management permission' do
    offer_for(product)
    allow_any_instance_of(SupplierPolicy).to receive(:manage_products?).and_return(false)

    get admin_supplier_supplier_products_path(supplier)

    expect(document.css("a[href='#{new_admin_supplier_supplier_product_path(supplier)}']")).to be_empty
    expect(document.css('a[href$="/edit"]')).to be_empty
    expect(document.css('[data-product-offer-row] form')).to be_empty
  end
end

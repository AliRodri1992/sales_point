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

  it 'recovers an archived offer while preserving its historical prices' do
    offer = offer_for(product)
    history_count = offer.price_history.count
    delete admin_supplier_supplier_product_path(supplier, offer)

    get history_admin_supplier_supplier_product_path(supplier, offer)
    expect(response).to have_http_status(:ok)
    get admin_supplier_supplier_products_path(supplier, archived: '1')
    expect(response).to have_http_status(:ok)
    expect(document.text).to include(product.name)

    patch restore_admin_supplier_supplier_product_path(supplier, offer)
    expect(response).to redirect_to(admin_supplier_supplier_products_path(supplier, archived: '1'))
    expect(offer.reload).to be_active
    expect(offer.deleted_at).to be_nil
    expect(offer.price_history.count).to eq(history_count)
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
    offer_for(with_image, supplier_sku: 'PHOTO-SKU')
    with_image.update!(preferred_supplier: supplier)
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

  it 'shows one preference action per offer and an indicator for all supplier presentations' do
    first = offer_for(product)
    second = offer_for(product, presentation_name: 'Pack of 24')

    get admin_supplier_supplier_products_path(supplier)
    expect(document.css("form[action='#{set_preferred_admin_supplier_supplier_product_path(supplier, first)}']"))
      .to be_present

    post set_preferred_admin_supplier_supplier_product_path(supplier, first),
         params: { expected_supplier_id: '' }

    expect(response).to redirect_to(admin_supplier_supplier_products_path(supplier))
    expect(product.reload.preferred_supplier).to eq(supplier)

    get admin_supplier_supplier_products_path(supplier)
    expect(document.text).to include('Yes, preferred')
    expect(document.css("form[action='#{clear_preferred_admin_supplier_supplier_product_path(supplier, first)}']"))
      .to be_present
    expect(document.css("form[action='#{clear_preferred_admin_supplier_supplier_product_path(supplier, second)}']"))
      .to be_present
  end

  it 'rejects stale preference changes rather than silently overwriting another user' do
    first = offer_for(product)
    second_supplier = create(:supplier, organization:)
    second = offer_for(product, supplier: second_supplier, currency: second_supplier.currency)
    post set_preferred_admin_supplier_supplier_product_path(supplier, first),
         params: { expected_supplier_id: '' }
    expect(product.reload.preferred_supplier_id).to eq(supplier.id)

    post set_preferred_admin_supplier_supplier_product_path(second_supplier, second),
         params: { expected_supplier_id: '' }
    expect(product.reload.preferred_supplier_id).to eq(supplier.id)
    expect(flash[:alert]).to include('Another user')

    post set_preferred_admin_supplier_supplier_product_path(second_supplier, second),
         params: { expected_supplier_id: supplier.id }
    expect(product.reload.preferred_supplier_id).to eq(second_supplier.id)
  end

  it 'allows explicitly clearing the preference without selecting another supplier' do
    offer = offer_for(product)
    product.update!(preferred_supplier: supplier)

    post clear_preferred_admin_supplier_supplier_product_path(supplier, offer),
         params: { expected_supplier_id: supplier.id }

    expect(product.reload.preferred_supplier).to be_nil
    expect(flash[:notice]).to include('removed')
  end

  it 'keeps supplier preference commands protected by manage-products permission' do
    offer = offer_for(product)
    allow_any_instance_of(SupplierPolicy).to receive(:manage_products?).and_return(false)

    get admin_supplier_supplier_products_path(supplier)
    expect(document.css("form[action='#{set_preferred_admin_supplier_supplier_product_path(supplier, offer)}']"))
      .to be_empty

    post set_preferred_admin_supplier_supplier_product_path(supplier, offer),
         params: { expected_supplier_id: '' }
    expect(product.reload.preferred_supplier).to be_nil
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

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial catalog administration', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:product) { create(:product, organization:, price: 100) }

  before do
    create(:organization_membership, user: administrator, organization:)
    create(:currency, code: 'MXN')
    sign_in administrator
  end

  it 'creates variants, conversions and alternate codes in the same product request' do
    post admin_products_path, params: { product: {
      name: 'Shirt', code: 'SHIRT', price: 100,
      product_variants_attributes: { '0' => { name: 'Blue M', sku: 'BLUE-M', size: 'M', color: 'Blue' } },
      product_presentations_attributes: { '0' => { name: 'Box', units: 12 } },
      product_barcodes_attributes: { '0' => { value: '7501001001001', symbology: 'ean13' } }
    } }
    expect(response).to have_http_status(:redirect)
    record = organization.products.find_by!(code: 'SHIRT')
    expect(record.product_variants.sole.options).to include('size' => 'M', 'color' => 'Blue')
    expect(record.product_presentations.sole.units).to eq(12)
    expect(record.product_barcodes.sole.organization_id).to eq(organization.id)
    get admin_products_path(search: '7501001001001')
    expect(response.body).to include('Shirt')
  end

  it 'creates a price list, renders every screen and records price changes with their reason' do
    post admin_price_lists_path, params: { price_list: {
      name: 'Retail', code: 'RETAIL', currency: 'MXN', status: 'active',
      price_list_items_attributes: { '0' => { product_id: product.id, price: 90 } }
    } }
    expect(response).to have_http_status(:see_other)
    list = organization.price_lists.sole
    [admin_price_lists_path, new_admin_price_list_path, admin_price_list_path(list),
     edit_admin_price_list_path(list)].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('translation_missing')
    end
    item = list.price_list_items.sole
    patch admin_price_list_path(list), params: { price_list: {
      price_list_items_attributes: { '0' => { id: item.id, product_id: product.id, price: 85 } }
    } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(item.reload.price).to eq(90)
    patch admin_price_list_path(list), params: { price_change_reason: 'Wholesale review', price_list: {
      price_list_items_attributes: { '0' => { id: item.id, product_id: product.id, price: 85 } }
    } }
    expect(response).to have_http_status(:see_other)
    expect(item.reload.price).to eq(85)
    expect(item.price_change_events.last).to have_attributes(previous_price: 90, new_price: 85,
                                                             reason: 'Wholesale review')
    delete admin_price_list_path(list)
    expect(list.reload).to be_archived
  end

  it 'creates a promotion, renders every screen and archives it without losing usage history' do
    post admin_promotions_path, params: { promotion: {
      name: 'Summer', code: 'SUMMER', currency: 'MXN', status: 'active', usage_limit: 10,
      promotion_conditions_attributes: { '0' => { kind: 'product', product_id: product.id } },
      promotion_benefits_attributes: { '0' => { kind: 'percentage', value: 15 } }
    } }
    expect(response).to have_http_status(:see_other)
    promotion = organization.promotions.sole
    [admin_promotions_path, new_admin_promotion_path, admin_promotion_path(promotion),
     edit_admin_promotion_path(promotion)].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('translation_missing')
    end
    patch admin_promotion_path(promotion), params: { promotion: { name: 'Revised summer' } }
    expect(response).to have_http_status(:see_other)
    delete admin_promotion_path(promotion)
    expect(response).to have_http_status(:see_other)
    expect(promotion.reload).to be_archived
    expect(promotion.promotion_benefits.sole.value).to eq(15)
  end

  it 'shows name and code errors beside each field without a duplicate summary' do
    post admin_price_lists_path, params: { price_list: { name: '', code: '', currency: 'MXN', status: 'draft' } }

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('.catalog-error')).to be_nil
    expect(document.text).not_to include(I18n.t('admin.catalog_design.fix_errors'))
    expect(document.at_css('#price_list_name_error')).to be_present
    expect(document.at_css('#price_list_code_error')).to be_present
  end

  it 'previews prices without consuming promotions or accepting a foreign option' do
    get quote_admin_product_path(product), params: { quantity: 2 }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('total' => '200.0')
    expect(PromotionRedemption.count).to eq(0)
    get quote_admin_product_path(product), params: { quantity: 0 }
    expect(response).to have_http_status(:unprocessable_content)
    foreign = create(:product).product_presentations.create!(name: 'Other', units: 12)
    get quote_admin_product_path(product), params: { presentation_id: foreign.id }
    expect(response).to have_http_status(:redirect)
  end

  it 'does not permit a nested row to move from another product or tenant' do
    foreign = create(:product).product_variants.create!(name: 'Foreign')
    patch admin_product_path(product), params: { product: {
      product_variants_attributes: { '0' => { id: foreign.id, name: 'Stolen' } }
    } }
    expect(response).to redirect_to(admin_products_path)
    expect(foreign.reload.name).to eq('Foreign')
  end

  it 'keeps older price requests accessible through the complete paginated history' do
    oldest = product.price_change_events.create!(organization:, actor: administrator, status: 'pending',
                                                 new_price: 110, previous_price: 100, currency: 'MXN',
                                                 reason: 'Oldest pending request')
    11.times do |number|
      product.price_change_events.create!(organization:, actor: administrator, status: 'approved',
                                          approved_by: administrator, approved_at: Time.current,
                                          new_price: 100, previous_price: 100, currency: 'MXN',
                                          reason: "Recent review #{number}")
    end
    get admin_product_path(product, page: -1, per_page: 5)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('table-per-page-product_price_history')
    expect(response.body).not_to include('Oldest pending request')
    get admin_product_path(product, page: 999, per_page: 5)
    expect(response.body).to include('Oldest pending request')
    expect(response.body).to include(admin_price_change_event_path(oldest, decision: 'approved'))
    expect(response.body).to include('12 · 3 / 3')
  end

  it 'keeps the primary scanner code synchronized when nested parameters attempt to change it' do
    product.update!(barcode: 'PRIMARY-CODE')
    code = product.product_barcodes.find_by!(primary: true)
    patch admin_product_path(product), params: { product: {
      product_barcodes_attributes: { '0' => { id: code.id, value: 'DIVERGENT-CODE' } }
    } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(code.reload.value).to eq('PRIMARY-CODE')
    expect(product.reload.barcode).to eq('PRIMARY-CODE')
    patch admin_product_path(product), params: { product: { barcode: 'REPLACEMENT-CODE' } }
    expect(response).to have_http_status(:redirect)
    expect(product.reload.product_barcodes.find_by!(primary: true).value).to eq('REPLACEMENT-CODE')
  end
end

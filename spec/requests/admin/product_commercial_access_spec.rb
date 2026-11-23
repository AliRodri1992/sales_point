# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial access from Products', type: :request do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:, price: 100) }
  let(:user) { create(:user, :english) }
  let(:role) { create(:system_role, :system) }
  let(:list) do
    organization.price_lists.create!(name: 'Private wholesale list', currency: 'MXN', status: 'active',
                                     price_list_items_attributes: [{ product:, price: 80 }])
  end

  before do
    create(:currency, code: 'MXN')
    create(:organization_membership, organization:, user:)
    create(:user_role, organization:, user:, system_role: role)
    grant('products.access', 'products.show')
    sign_in user
  end

  def grant(*codes)
    codes.each do |code|
      permission = Permission.find_by(code:) || create(:permission, code:)
      create(:system_role_permission, permission:, system_role: role)
    end
  end

  it 'only renders the price-list picker when the reader can list and open price lists' do
    list.update!(customer_segment: 'Private customer segment')

    get admin_product_path(product)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(list.name, list.customer_segment)
    expect(Nokogiri::HTML(response.body).at_css('#quote-priceList')).to be_nil

    grant('price_lists.access', 'price_lists.index', 'price_lists.show')
    get admin_product_path(product)
    picker = Nokogiri::HTML(response.body).at_css('#quote-priceList')
    expect(picker.at_css("option[value='#{list.id}']").text).to include(list.name, list.customer_segment)
  end

  it 'requires the list detail grant to quote its price explicitly' do
    grant('price_lists.access', 'price_lists.index')
    get quote_admin_product_path(product), params: { price_list_id: list.id }
    expect(response).to have_http_status(:forbidden)

    grant('price_lists.show')
    get quote_admin_product_path(product), params: { price_list_id: list.id }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('total' => '80.0')
    expect(response.body).not_to include(list.name)
  end

  it 'cannot quote an explicitly selected list from another organization' do
    grant('price_lists.access', 'price_lists.show')
    foreign_list = create(:organization).price_lists.create!(name: 'Foreign list', currency: 'MXN')

    get quote_admin_product_path(product), params: { price_list_id: foreign_list.id }

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(foreign_list.name)
  end

  it 'rejects malformed quote options and segment values' do
    variant = product.product_variants.create!(name: 'Example variant')
    [{ variant_id: [variant.id] }, { customer_segment: { name: 'Wholesale' } }].each do |options|
      get quote_admin_product_path(product), params: options

      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'keeps the automatic discount but requires promotion detail permission to disclose its name' do
    promotion = organization.promotions.create!(
      name: 'Private campaign', currency: 'MXN', status: 'active',
      promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }]
    )

    get quote_admin_product_path(product)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('discount' => '10.0', 'total' => '90.0', 'promotion' => nil)

    grant('promotions.access', 'promotions.show')
    get quote_admin_product_path(product)
    expect(response.parsed_body).to include('total' => '90.0', 'promotion' => promotion.name)
  end
end

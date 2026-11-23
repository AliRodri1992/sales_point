# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Product price history', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }
  let(:role) { create(:system_role, :system) }
  let(:product) { create(:product, organization:, price: 100) }
  let(:list_item) do
    list = organization.price_lists.create!(name: 'Wholesale', currency: 'MXN')
    list.price_list_items.create!(product:, price: 95)
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

  def record_price_event(reason:, price_list_item: nil)
    product.price_change_events.create!(organization:, actor: user, previous_price: 100, new_price: 95,
                                        currency: 'MXN', reason:, price_list_item:)
  end

  it 'shows base-price history and requires a separate grant to reveal list-price events' do
    record_price_event(reason: 'Base price review')
    record_price_event(reason: 'Confidential list price review', price_list_item: list_item)
    grant('price_lists.access', 'price_lists.show')

    get admin_product_path(product)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Base price review')
    expect(response.body).not_to include('Confidential list price review')

    grant('price_lists.history')
    get admin_product_path(product)
    expect(response.body).to include('Confidential list price review')
  end

  it 'keeps price-list events outside the base-price approval route for administrators' do
    admin = create(:system_role, :system, code: 'administrator')
    create(:user_role, organization:, user:, system_role: admin)
    event = record_price_event(reason: 'List price review', price_list_item: list_item)

    get admin_product_path(product)
    expect(response.body).to include('List price review')
    expect(response.body).not_to include(admin_price_change_event_path(event, decision: 'approved'))

    patch admin_price_change_event_path(event), params: { decision: 'approved' }

    expect(response).to have_http_status(:not_found)
    expect(event.reload).to be_pending
    expect(product.reload.price).to eq(100)
  end
end

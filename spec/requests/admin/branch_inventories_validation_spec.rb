# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Branch inventory field validations', type: :request do
  let(:organization) { create(:organization) }
  let(:admin) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:branch) { create(:branch, organization:) }

  before do
    create(:organization_membership, organization:, user: admin)
    sign_in admin
  end

  it 'rejects missing products with errors directly under the product selector' do
    post admin_branch_inventories_path(branch), params: {
      inventory: { product_id: '', min_stock: 0, max_stock: 10 }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('inventory-product-error')
    document = Nokogiri::HTML(response.body)
    product_field = document.at_css('select[name="inventory[product_id]"]')
    expect(product_field).to be_present
    expect(product_field['required']).to be_nil
    expect(branch.inventories.count).to eq(0)
  end

  it 'rejects invalid stock limits under their corresponding fields' do
    product = create(:product, organization:)
    post admin_branch_inventories_path(branch), params: {
      inventory: { product_id: product.id, min_stock: -1, max_stock: -2 }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('inventory-min_stock-error', 'inventory-max_stock-error')
  end

  it 'offers lot selection and updates lot and aggregate stock together' do
    product = create(:product, organization:, tracking_mode: 'lot')
    inventory = create(:inventory, organization:, branch:, product:, stock: 5)
    lot = InventoryLot.create!(
      organization:, inventory:, code: 'WEB-LOT-001', quantity: 5, status: :available
    )

    get admin_branch_inventories_path(branch)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css("select[name='inventory_lot_id']")).to be_present

    post adjust_admin_branch_inventory_path(branch, inventory),
         params: { quantity: -2, inventory_lot_id: lot.id }

    expect(response).to have_http_status(:see_other)
    expect(inventory.reload.stock).to eq(3)
    expect(lot.reload.quantity).to eq(3)
  end

  it 'shows lot errors underneath the selector when a tracked adjustment omits the lot' do
    product = create(:product, organization:, tracking_mode: 'lot')
    inventory = create(:inventory, organization:, branch:, product:, stock: 3)

    post adjust_admin_branch_inventory_path(branch, inventory), params: { quantity: -1 }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("inventory-lot-error-#{inventory.id}")
    expect(inventory.reload.stock).to eq(3)
  end

  it 'does not expose unsafe manual adjustments for serialized products' do
    product = create(:product, organization:, tracking_mode: 'serial')
    inventory = create(:inventory, organization:, branch:, product:, stock: 1)

    get admin_branch_inventories_path(branch)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('admin.branch_lifecycle.serial_adjustment_notice'))
    expect(response.body).not_to include(adjust_admin_branch_inventory_path(branch, inventory))
  end

  it 'shows adjustment errors next to quantity without modifying stock' do
    inventory = create(:inventory, organization:, branch:, stock: 5)
    post adjust_admin_branch_inventory_path(branch, inventory), params: { quantity: '' }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("inventory-quantity-error-#{inventory.id}")
    expect(inventory.reload.stock).to eq(5)
  end
end

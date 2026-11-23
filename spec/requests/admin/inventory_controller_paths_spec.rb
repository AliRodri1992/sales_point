# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inventory administration controller paths', type: :request do
  include SqlQueryRecorder

  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:product) { create(:product, organization:) }
  let(:actor) { create(:user) }

  before do
    create(:organization_membership, user: actor, organization:)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in actor
  end

  it 'loads the latest five movements for all inventories in one query', :n_plus_one do
    2.times do |index|
      stock = Inventory.create!(
        organization:, branch:, product: create(:product, organization:),
        stock: 7, min_stock: 0
      )
      7.times do |movement|
        minutes_ago = (index * 10) + movement
        InventoryMovement.create!(
          organization:, inventory: stock, kind: 'adjustment', quantity: 1,
          stock_before: movement, stock_after: movement + 1,
          created_at: minutes_ago.minutes.ago
        )
      end
    end

    statements = recorded_sql_queries { get admin_branch_inventories_path(branch) }
    expect(response).to have_http_status(:ok)
    expect(statements.grep(/ROW_NUMBER\(\) OVER/).size).to eq(1)
  end

  it 'displays inventories for a branch' do
    get admin_branch_inventories_path(branch)
    expect(response).to have_http_status(:ok)
  end

  it 'creates a new inventory for an organization product' do
    post admin_branch_inventories_path(branch), params: {
      inventory: { product_id: product.id, min_stock: 2, max_stock: 20 }
    }
    expect(response).to redirect_to(admin_branch_inventories_path(branch))
    expect(Inventory.find_by!(branch:, product:).min_stock).to eq(2)
  end

  it 'rejects duplicate inventory stock rows' do
    Inventory.create!(organization:, branch:, product:, min_stock: 1, stock: 0)
    post admin_branch_inventories_path(branch), params: {
      inventory: { product_id: product.id, min_stock: 2 }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('inventory-product-id-error')
    expect(Inventory.where(branch:, product:).count).to eq(1)
  end

  it 'updates stock thresholds without directly editing stock' do
    stock = Inventory.create!(organization:, branch:, product:, stock: 5, min_stock: 1)
    patch admin_branch_inventory_path(branch, stock), params: {
      inventory: { min_stock: 3, max_stock: 12 }
    }
    expect(response).to redirect_to(admin_branch_inventories_path(branch))
    expect(stock.reload).to have_attributes(stock: 5, min_stock: 3, max_stock: 12)
  end

  it 'rejects incompatible inventory thresholds' do
    stock = Inventory.create!(organization:, branch:, product:, stock: 5, min_stock: 1)
    patch admin_branch_inventory_path(branch, stock), params: {
      inventory: { min_stock: 10, max_stock: 5 }
    }
    expect(response).to have_http_status(:unprocessable_content)
    form = Nokogiri::HTML(response.body).at_css("form[action='#{admin_branch_inventory_path(branch, stock)}']")
    expect(form.at_css('[role="alert"]').text).to include(I18n.t('admin.inventory.max_stock'))
    expect(stock.reload).to have_attributes(min_stock: 1, max_stock: nil)
  end

  it 'rejects invalid adjustment quantities' do
    stock = Inventory.create!(organization:, branch:, product:, stock: 5, min_stock: 1)
    post adjust_admin_branch_inventory_path(branch, stock), params: { quantity: 'invalid' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("inventory-quantity-error-#{stock.id}")
  end

  it 'blocks inventory in another organization branch' do
    foreign_branch = create(:branch, organization: create(:organization))
    get admin_branch_inventories_path(foreign_branch)
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects new rows and threshold changes while operations are suspended' do
    stock = create(:inventory, organization:, branch:, stock: 3)
    Branches::TransitionStatus.call(branch:, actor:, to: 'suspended', reason: 'Maintenance')

    expect do
      post admin_branch_inventories_path(branch), params: { inventory: { product_id: product.id } }
    end.not_to change(Inventory, :count)
    expect(response).to have_http_status(:forbidden)

    patch admin_branch_inventory_path(branch, stock), params: { inventory: { min_stock: 2 } }
    expect(response).to have_http_status(:forbidden)
    expect(stock.reload.min_stock).to eq(10)
  end

  it 'rejects branch access when the signed-in user has no organization' do
    sign_out actor
    sign_in create(:user)

    get admin_branch_inventories_path(branch)

    expect(response).to have_http_status(:forbidden)
  end

  it 'returns a quantity error when the adjustment exceeds the balance' do
    stock = create(:inventory, organization:, branch:, stock: 1)
    post adjust_admin_branch_inventory_path(branch, stock), params: { quantity: -2 }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t('admin.branch_lifecycle.inventory_quantity_rejected'))
    expect(stock.reload.stock).to eq(1)
    expect(stock.inventory_movements).to be_empty
  end
end

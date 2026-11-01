# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inventory administration controller paths', type: :request do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:product) { create(:product, organization:) }
  let(:actor) { create(:user) }

  before do
    create(:organization_membership, user: actor, organization:)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in actor
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
    expect(response).to redirect_to(admin_branch_inventories_path(branch))
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
    expect(response).to redirect_to(admin_branch_inventories_path(branch))
    expect(stock.reload.min_stock).to eq(1)
  end

  it 'rejects invalid adjustment quantities' do
    stock = Inventory.create!(organization:, branch:, product:, stock: 5, min_stock: 1)
    post adjust_admin_branch_inventory_path(branch, stock), params: { quantity: 'invalid' }
    expect(response).to redirect_to(admin_branch_inventories_path(branch))
  end

  it 'blocks inventory in another organization branch' do
    foreign_branch = create(:branch, organization: create(:organization))
    get admin_branch_inventories_path(foreign_branch)
    expect(response).to have_http_status(:not_found)
  end
end

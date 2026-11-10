# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inventory overview and branch operations', type: :request do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:admin) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, organization:, user: admin)
    sign_in admin
  end

  it 'shows stock across authorized branches and a stock summary' do
    product = create(:product, organization:, name: 'Filtro de aceite')
    create(:inventory, organization:, branch:, product:, stock: 4, min_stock: 6)

    get admin_inventory_overview_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Filtro de aceite', branch.name)
    expect(response.body).to include(I18n.t('admin.inventory.overview_title'))
    expect(response.body).to include(I18n.t('admin.inventory.stock_statuses.low'))
  end

  it 'never exposes another organization even with a matching search' do
    foreign = create(:organization)
    foreign_branch = create(:branch, organization: foreign)
    foreign_product = create(:product, organization: foreign, name: 'PRODUCTO EXTERNO PRIVADO')
    create(:inventory, organization: foreign, branch: foreign_branch, product: foreign_product)

    get admin_inventory_overview_path, params: { search: 'EXTERNO' }

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('PRODUCTO EXTERNO PRIVADO')
  end

  it 'filters stock statuses and tracking modes without listing unrelated products' do
    low_product = create(:product, organization:, name: 'ARTICULO BAJO', tracking_mode: 'lot')
    ok_product = create(:product, organization:, name: 'ARTICULO NORMAL')
    create(:inventory, organization:, branch:, product: low_product, stock: 2, min_stock: 4)
    create(:inventory, organization:, branch:, product: ok_product, stock: 15, min_stock: 3)

    get admin_inventory_overview_path, params: { status: 'low', tracking: 'lot' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ARTICULO BAJO')
    expect(response.body).not_to include('ARTICULO NORMAL')
    expect(response.body).to include(I18n.t('admin.inventory.filters.active'))
  end

  it 'ignores unrecognized filter values without interpolating them into SQL' do
    create(:inventory, organization:, branch:)
    get admin_inventory_overview_path, params: { status: 'bad-value', tracking: 'bad-value', sort: 'DROP TABLE' }

    expect(response).to have_http_status(:ok)
  end

  it 'supports filtering a branch inventory directory by search and low stock' do
    product = create(:product, organization:, name: 'Tuerca especial')
    other = create(:product, organization:, name: 'Tornillo normal')
    create(:inventory, organization:, branch:, product:, stock: 2, min_stock: 5)
    create(:inventory, organization:, branch:, product: other, stock: 20, min_stock: 3)

    get admin_branch_inventories_path(branch), params: { search: 'Tuerca', status: 'low' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Tuerca especial')
    expect(response.body).not_to include('Tornillo normal')
  end

  it 'records manual adjustment references without allowing direct stock updates' do
    inventory = create(:inventory, organization:, branch:, stock: 8)

    post adjust_admin_branch_inventory_path(branch, inventory),
         params: { quantity: -2, reference: 'Conteo en almacén' }

    expect(response).to have_http_status(:see_other)
    expect(inventory.reload.stock).to eq(6)
    expect(inventory.inventory_movements.order(:id).last).to have_attributes(
      kind: 'adjustment', quantity: -2, reference: 'Conteo en almacén'
    )
  end


  it 'keeps inventory permissions scoped to the branch granting them' do
    other_branch = create(:branch, organization:)
    visible_product = create(:product, organization:, name: 'ARTICULO AUTORIZADO')
    hidden_product = create(:product, organization:, name: 'ARTICULO RESTRINGIDO')
    create(:inventory, organization:, branch:, product: visible_product)
    create(:inventory, organization:, branch: other_branch, product: hidden_product)

    employee = create(:user)
    create(:organization_membership, organization:, user: employee)
    inventory_role = create(:system_role, :branch)
    other_role = create(:system_role, :branch)
    permission = create(:permission, code: 'inventory.view')
    create(:system_role_permission, system_role: inventory_role, permission:)
    create(:user_role, user: employee, system_role: inventory_role, branch:)
    create(:user_role, user: employee, system_role: other_role, branch: other_branch)
    sign_out admin
    sign_in employee

    get admin_inventory_overview_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ARTICULO AUTORIZADO')
    expect(response.body).not_to include('ARTICULO RESTRINGIDO')

    get admin_branch_inventories_path(other_branch)
    expect(response).to have_http_status(:forbidden)
  end

  it 'allows organization-wide inventory roles across their organization' do
    product = create(:product, organization:, name: 'PRODUCTO GLOBAL')
    create(:inventory, organization:, branch:, product:)

    employee = create(:user)
    create(:organization_membership, organization:, user: employee)
    role = create(:system_role, :system)
    permission = create(:permission, code: 'inventory.access')
    create(:system_role_permission, system_role: role, permission:)
    create(:user_role, user: employee, system_role: role)
    sign_out admin
    sign_in employee

    get admin_branch_inventories_path(branch)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('PRODUCTO GLOBAL')
  end

  it 'denies inventory access to a member without inventory permissions' do
    employee = create(:user)
    create(:organization_membership, organization:, user: employee)
    sign_out admin
    sign_in employee

    get admin_inventory_overview_path

    expect(response).to have_http_status(:forbidden)
  end
end

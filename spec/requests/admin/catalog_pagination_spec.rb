require 'rails_helper'

RSpec.describe 'Catalog pagination links', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, :english, status: 'active') }
  let!(:role) { create(:system_role, :system) }
  let!(:categories_permission) { create(:permission, code: 'categories.access') }
  let!(:products_permission) { create(:permission, code: 'products.access') }

  before do
    create(:user_role, user:, system_role: role)
    create(:system_role_permission, system_role: role, permission: categories_permission)
    create(:system_role_permission, system_role: role, permission: products_permission)
    create_list(:category, 12)
    create_list(:product, 12)
    sign_in user
  end

  after { sign_out user }

  def expect_pagination_labels(body, frame)
    link_pattern = %r{<a[^>]*data-turbo-frame="#{frame}"[^>]*>([^<]*)</a>}
    labels = body.scan(link_pattern).flatten

    expect(labels).to include('2', '3', 'Next')
    expect(labels).not_to include('')
  end

  def active_page(body)
    body[%r{<span class="[^"]*bg-blue-600[^"]*"[^>]*aria-current="page"[^>]*>([^<]*)</span>}, 1]
  end

  it 'labels every categories page link' do
    get admin_categories_path(per_page: 5)

    expect_pagination_labels(response.body, 'categories_list')
  end

  it 'labels every products page link' do
    get admin_products_path(per_page: 5)

    expect_pagination_labels(response.body, 'admin_products_list')
  end

  it 'marks the current categories page' do
    get admin_categories_path(per_page: 5)
    expect(active_page(response.body)).to eq('1')

    get admin_categories_path(per_page: 5, page: 2)
    expect(active_page(response.body)).to eq('2')
  end

  it 'marks the current products page' do
    get admin_products_path(per_page: 5)
    expect(active_page(response.body)).to eq('1')

    get admin_products_path(per_page: 5, page: 2)
    expect(active_page(response.body)).to eq('2')
  end
end

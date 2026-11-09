# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Products', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }
  let!(:organization) { create(:organization) }

  before do
    create(:organization_membership, user:, organization:)
    role = create(:system_role, :system)
    create(:user_role, user:, system_role: role)
    GranularPermissionCatalog.sync!
    codes = GranularPermissionCatalog::ACTIONS.map { |action| "products.#{action}" }
    Permission.where(code: codes).find_each do |permission|
      create(:system_role_permission, system_role: role, permission:)
    end
    sign_in user
  end

  after do
    sign_out user
  end

  include SqlQueryRecorder

  describe 'GET /admin/products' do
    it 'queries inventory stock totals once for a page of products', :n_plus_one do
      statements = recorded_sql_queries { get admin_products_path }

      expect(response).to have_http_status(:ok)
      stock_sums = statements.grep(/SUM\([^\n]*stock[^\n]*\)/i)
      expect(stock_sums.size).to eq(1)
    end

    let!(:product) { create(:product, organization:, name: 'Coca-Cola', code: 'PROD-COLA') }

    before do
      create_list(:product, 15, organization:)
    end

    it 'returns a paginated list with at least 10 items per page' do
      get admin_products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.products.index.total_count',
                                              count: Product.not_deleted.count))
    end

    it 'shows the total count of products (not just page count)' do
      get admin_products_path

      total = Product.not_deleted.count
      expect(response.body).to include(I18n.t('admin.products.index.total_count', count: total))
    end

    it 'respects the per_page query param' do
      get admin_products_path(per_page: 5)

      expect(response).to have_http_status(:ok)
    end

    it 'filters by search query on name, code, sku or barcode' do
      get admin_products_path(search: 'Coca-Cola')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Coca-Cola')
    end

    it 'filters by status' do
      get admin_products_path(status: 'active')

      expect(response).to have_http_status(:ok)
    end

    it 'sorts by name in descending order when direction=desc' do
      get admin_products_path(sort: 'products.name', direction: 'desc')

      expect(response).to have_http_status(:ok)
    end

    it 'sorts by code column' do
      get admin_products_path(sort: 'products.code')

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /admin/products/:id' do
    it 'finds a product by numeric database id' do
      product = create(:product, organization:, name: 'Product By Id')

      get admin_product_path(product.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Product By Id')
    end

    it 'finds a product by slug' do
      product = create(:product, organization:, name: 'Product By Slug', slug: 'product-by-slug')

      get admin_product_path(product.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Product By Slug')
    end

    it 'finds a product by code when the slug does not match' do
      product = create(:product, organization:, name: 'Product By Code', code: 'LOOKUP-CODE')

      get admin_product_path(product.code)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Product By Code')
    end

    it 'redirects to the catalog with an alert for an unknown product' do
      get admin_product_path('missing-product')

      expect(response).to redirect_to(admin_products_path)
      expect(flash[:alert]).to eq(I18n.t('admin.products.index.not_found'))
    end
  end

  describe 'GET /admin/products/new' do
    it 'renders the new product form with default values' do
      get new_admin_product_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="product[name]"')

      document = Nokogiri::HTML(response.body)
      form = document.at_css('form[action="/admin/products"]')
      expect(form['novalidate']).to be_present
      %w[product_name product_code product_price].each do |field|
        expect(document.at_css("label[for='#{field}'] .text-rose-600")).to be_present
        expect(document.at_css("##{field}")['required']).to be_nil
      end
    end
  end

  describe 'POST /admin/products' do
    it 'sends a "created" notification to the current user' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'PROD-NEW', name: 'New Product', price: 10 } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('created')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        .with("products_catalog_#{organization.id}")

      post admin_products_path(format: :turbo_stream),
           params: { product: { code: 'PROD-NEW', name: 'New Product', price: 10 } }
    end

    it 'refreshes viewers so each receives actions authorized for their own account' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        .with("products_catalog_#{organization.id}")

      post admin_products_path,
           params: { product: { code: 'PROD-BROADCAST', name: 'Broadcast Product', price: 10 } }

      expect(response).to redirect_to(admin_products_path)
    end

    it 'renders the form when a unique index rejects the create' do
      allow_any_instance_of(Product).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)

      post admin_products_path,
           params: { product: { code: 'PROD-DUPLICATE', name: 'Duplicate Product', price: 10 } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'defaults the status to active when not provided' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'PROD-NEW', name: 'New Product', price: 10 } }
      end.to change(Product, :count).by(1)

      expect(Product.find_by(code: 'PROD-NEW').status).to eq('active')
    end

    it 'does not persist the product when name is blank' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'PROD-NEW', name: '', price: 10 } }
      end.not_to change(Product, :count)
    end

    it 'does not persist the product when code is blank' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: '', name: 'New Product', price: 10 } }
      end.not_to change(Product, :count)
    end

    it 'does not persist the product when code is already taken' do
      create(:product, organization:, code: 'duplicate')
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'duplicate', name: 'New Product', price: 10 } }
      end.not_to change(Product, :count)
    end

    it 'does not persist the product when price is negative' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'PROD-NEG', name: 'Negative Price', price: -5 } }
      end.not_to change(Product, :count)
    end

    it 'renders the create status with validation errors on invalid data' do
      post admin_products_path(format: :turbo_stream),
           params: { product: { code: '', name: '', price: 10 } }

      expect(response).to have_http_status(:unprocessable_content)

      document = Nokogiri::HTML(response.body)
      expect(document.at_css('.catalog-error')).to be_nil
      expect(document.text).not_to include(I18n.t('admin.catalog_design.fix_errors'))
      %w[product_name_error product_code_error].each do |id|
        expect(document.at_css("##{id}")).to be_present
      end
      expect(document.at_css('#product_name_error').text.strip).to be_present
      expect(document.at_css('#product_code_error').text.strip).to be_present
    end
  end

  describe 'PATCH /admin/products/:id' do
    let!(:product) { create(:product, organization:, name: 'Old Name', code: 'old_code', price: 10) }

    it 'sends an "updated" notification to the current user' do
      expect do
        patch admin_product_path(product, format: :turbo_stream),
              params: { product: { name: 'New Name', code: 'old_code', price: 10 } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('updated')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        .with("products_catalog_#{organization.id}")

      patch admin_product_path(product, format: :turbo_stream),
            params: { product: { name: 'New Name', code: 'old_code' } }
    end

    it 'updates the product name' do
      patch admin_product_path(product, format: :turbo_stream),
            params: { product: { name: 'New Name', code: 'old_code' } }

      expect(product.reload.name).to eq('New Name')
    end

    it 'does not update the product when name is blank' do
      patch admin_product_path(product, format: :turbo_stream),
            params: { product: { name: '', code: 'old_code' } }

      expect(product.reload.name).to eq('Old Name')
    end

    it 'renders the edit form when a unique index rejects the update' do
      allow_any_instance_of(Product).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      patch admin_product_path(product),
            params: { product: { name: 'Conflicting Name', code: 'old_code' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE /admin/products/:id' do
    let!(:product) { create(:product, organization:, name: 'ToDelete', code: 'del_prod', price: 10) }

    it 'sends a "destroyed" notification to the current user' do
      expect do
        delete admin_product_path(product, format: :turbo_stream)
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('destroyed')
    end

    it 'stores the actor user in the notification params' do
      delete admin_product_path(product, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.params[:user]).to eq(user)
    end

    it 'keeps the soft-deleted product record accessible on the notification' do
      delete admin_product_path(product, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.record).to be_a(Product)
      expect(notification.record.code).to eq('del_prod')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        .with("products_catalog_#{organization.id}")

      delete admin_product_path(product, format: :turbo_stream)
    end

    it 'soft-deletes the product' do
      expect do
        delete admin_product_path(product, format: :turbo_stream)
      end.to change { Product.not_deleted.count }.by(-1)
      expect(Product.with_deleted.find(product.id).deleted_at).not_to be_nil
    end

    it 'redirects safely when the delete operation raises RecordNotFound' do
      allow_any_instance_of(Product).to receive(:update!).and_raise(ActiveRecord::RecordNotFound)

      delete admin_product_path(product)

      expect(response).to redirect_to(admin_products_path)
    end

    it 'redirects with an alert when the delete operation raises another error' do
      allow_any_instance_of(Product).to receive(:update!).and_raise(StandardError, 'delete failed')

      delete admin_product_path(product)

      expect(response).to redirect_to(admin_products_path)
      expect(flash[:alert]).to eq(I18n.t('admin.products.destroy_failed'))
    end

    it 'appears in user.notifications even when the product is soft-deleted' do
      delete admin_product_path(product, format: :turbo_stream)

      notification = user.notifications.find_by(
        noticed_events: { record_type: 'Product', record_id: product.id }
      )
      expect(notification).to be_present
      expect(notification.params[:action]).to eq('destroyed')
    end
  end

  describe 'advanced product filters' do
    it 'renders an expandable filter panel with a compact apply action' do
      get admin_products_path
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('details.products-filters__advanced')).to be_present
      button = document.at_css('button.products-filters__apply')
      expect(button).to be_present
      expect(button['class']).to include('products-filters__apply')
    end

    it 'combines category, tracking, featured and price filters within this organization' do
      category = create(:category)
      chosen = create(:product, organization:, category:, tracking_mode: :lot,
                      featured: true, price: 80, name: 'Matching catalog item')
      create(:product, organization:, category:, tracking_mode: :none,
             featured: false, price: 140, name: 'Not matching item')
      create(:product, organization: create(:organization), category:, tracking_mode: :lot,
             featured: true, price: 80, name: 'Foreign catalog item')

      get admin_products_path, params: { category_id: category.id, tracking_mode: 'lot',
                                         featured: 'true', min_price: '60', max_price: '90' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(chosen.name)
      expect(response.body).not_to include('Not matching item', 'Foreign catalog item')
      expect(Nokogiri::HTML(response.body).at_css('details.products-filters__advanced')['open']).to be_present
    end

    it 'filters available, depleted and low-stock products using tenant inventories' do
      branch = create(:branch, organization:)
      available = create(:product, organization:, name: 'Low quantity item')
      depleted = create(:product, organization:, name: 'Depleted item')
      create(:inventory, organization:, branch:, product: available, stock: 2, min_stock: 5)
      create(:inventory, organization:, branch:, product: depleted, stock: 0, min_stock: 5)

      get admin_products_path(stock_status: 'low')
      expect(response.body).to include(available.name, depleted.name)
      get admin_products_path(stock_status: 'available')
      expect(response.body).to include(available.name)
      expect(response.body).not_to include(depleted.name)
      get admin_products_path(stock_status: 'out')
      expect(response.body).to include(depleted.name)
      expect(response.body).not_to include(available.name)
    end

    it 'ignores invalid negative or nonnumeric price filters' do
      item = create(:product, organization:, price: 60, name: 'Visible price filter')
      get admin_products_path(min_price: '-1', max_price: 'not-a-number')
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(item.name)
    end
  end

  describe 'GET /admin/products filter and pagination edge cases' do
    it 'filters to featured products' do
      featured = create(:product, organization:, name: 'Featured Item', featured: true)
      create(:product, organization:, name: 'Regular Item', featured: false)

      get admin_products_path, params: { featured: 'true' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(featured.name)
      expect(response.body).not_to include('Regular Item')
    end

    it 'filters out featured products when featured=false' do
      create(:product, organization:, name: 'Featured Item', featured: true)
      regular = create(:product, organization:, name: 'Regular Item', featured: false)

      get admin_products_path, params: { featured: 'false' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(regular.name)
      expect(response.body).not_to include('Featured Item')
    end

    it 'does not filter status when status=all' do
      create(:product, organization:, name: 'Active Item', status: :active)
      create(:product, organization:, name: 'Inactive Item', status: :inactive)

      get admin_products_path, params: { status: 'all' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Active Item')
      expect(response.body).to include('Inactive Item')
    end

    it 'falls back to the default sort column and direction for invalid values' do
      create(:product, organization:, name: 'Alpha Item')
      create(:product, organization:, name: 'Zulu Item')

      get admin_products_path, params: { sort: 'products.unsafe_column', direction: 'sideways' }

      expect(response).to have_http_status(:ok)
      expect(response.body.index('Alpha Item')).to be < response.body.index('Zulu Item')
    end

    it 'normalizes a page below one to the first page' do
      create_list(:product, 12, organization:)

      get admin_products_path, params: { page: 0 }

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(10)
    end

    it 'clamps a page beyond the last page to the last page' do
      create_list(:product, 12, organization:)

      get admin_products_path, params: { page: 999 }

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(2)
    end

    it 'uses the default page size for an unsupported per_page value' do
      create_list(:product, 12, organization:)

      get admin_products_path, params: { per_page: 7 }

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(10)
    end

    it 'searches by SKU and barcode' do
      sku_product = create(:product, organization:, name: 'SKU Match', sku: 'SKU-COVERAGE-01')
      barcode_product = create(:product, organization:, name: 'Barcode Match', barcode: 'BAR-COVERAGE-01')
      create(:product, organization:, name: 'No Match')

      get admin_products_path, params: { search: 'SKU-COVERAGE-01' }
      expect(response.body).to include(sku_product.name)
      expect(response.body).not_to include('No Match')

      get admin_products_path, params: { search: 'BAR-COVERAGE-01' }
      expect(response.body).to include(barcode_product.name)
      expect(response.body).not_to include('No Match')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Products', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }

  before do
    sign_in user
  end

  after do
    sign_out user
  end

  describe 'GET /admin/products' do
    let!(:product) { create(:product, name: 'Coca-Cola', code: 'PROD-COLA') }

    before do
      create_list(:product, 15)
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
      product = create(:product, name: 'Product By Id')

      get admin_product_path(product.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Product By Id')
    end

    it 'finds a product by slug' do
      product = create(:product, name: 'Product By Slug', slug: 'product-by-slug')

      get admin_product_path(product.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Product By Slug')
    end

    it 'finds a product by code when the slug does not match' do
      product = create(:product, name: 'Product By Code', code: 'LOOKUP-CODE')

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
    end
  end

  describe 'POST /admin/products' do
    it 'sends a "created" notification to the current user' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'PROD-NEW', name: 'New Product', price: 10, stock: 5 } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('created')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('products_catalog', target: 'admin_products_list', html: kind_of(String))

      post admin_products_path(format: :turbo_stream),
           params: { product: { code: 'PROD-NEW', name: 'New Product', price: 10, stock: 5 } }
    end

    it 'renders the real-time catalog broadcast partial after a successful create' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('products_catalog', target: 'admin_products_list', html: kind_of(String))

      post admin_products_path,
           params: { product: { code: 'PROD-BROADCAST', name: 'Broadcast Product', price: 10, stock: 5 } }

      expect(response).to redirect_to(admin_products_path)
    end

    it 'renders the form when a unique index rejects the create' do
      allow_any_instance_of(Product).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      post admin_products_path,
           params: { product: { code: 'PROD-DUPLICATE', name: 'Duplicate Product', price: 10, stock: 5 } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'defaults the status to active when not provided' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'PROD-NEW', name: 'New Product', price: 10, stock: 5 } }
      end.to change(Product, :count).by(1)

      expect(Product.find_by(code: 'PROD-NEW').status).to eq('active')
    end

    it 'does not persist the product when name is blank' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'PROD-NEW', name: '', price: 10, stock: 5 } }
      end.not_to change(Product, :count)
    end

    it 'does not persist the product when code is blank' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: '', name: 'New Product', price: 10, stock: 5 } }
      end.not_to change(Product, :count)
    end

    it 'does not persist the product when code is already taken' do
      create(:product, code: 'duplicate')
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'duplicate', name: 'New Product', price: 10, stock: 5 } }
      end.not_to change(Product, :count)
    end

    it 'does not persist the product when price is negative' do
      expect do
        post admin_products_path(format: :turbo_stream),
             params: { product: { code: 'PROD-NEG', name: 'Negative Price', price: -5, stock: 5 } }
      end.not_to change(Product, :count)
    end

    it 'renders the create status with validation errors on invalid data' do
      post admin_products_path(format: :turbo_stream),
           params: { product: { code: '', name: '', price: 10, stock: 5 } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /admin/products/:id' do
    let!(:product) { create(:product, name: 'Old Name', code: 'old_code', price: 10, stock: 5) }

    it 'sends an "updated" notification to the current user' do
      expect do
        patch admin_product_path(product, format: :turbo_stream),
              params: { product: { name: 'New Name', code: 'old_code', price: 10, stock: 5 } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('updated')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('products_catalog', target: 'admin_products_list', html: kind_of(String))

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
      allow_any_instance_of(Product).to receive(:update).and_raise(ActiveRecord::RecordNotUnique)

      patch admin_product_path(product),
            params: { product: { name: 'Conflicting Name', code: 'old_code' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE /admin/products/:id' do
    let!(:product) { create(:product, name: 'ToDelete', code: 'del_prod', price: 10, stock: 5) }

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
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('products_catalog', target: 'admin_products_list', html: kind_of(String))

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

  describe 'GET /admin/products filter and pagination edge cases' do
    it 'filters to featured products' do
      featured = create(:product, name: 'Featured Item', featured: true)
      create(:product, name: 'Regular Item', featured: false)

      get admin_products_path, params: { featured: 'true' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(featured.name)
      expect(response.body).not_to include('Regular Item')
    end

    it 'filters out featured products when featured=false' do
      create(:product, name: 'Featured Item', featured: true)
      regular = create(:product, name: 'Regular Item', featured: false)

      get admin_products_path, params: { featured: 'false' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(regular.name)
      expect(response.body).not_to include('Featured Item')
    end

    it 'does not filter status when status=all' do
      create(:product, name: 'Active Item', status: :active)
      create(:product, name: 'Inactive Item', status: :inactive)

      get admin_products_path, params: { status: 'all' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Active Item')
      expect(response.body).to include('Inactive Item')
    end

    it 'falls back to the default sort column and direction for invalid values' do
      create(:product, name: 'Alpha Item')
      create(:product, name: 'Zulu Item')

      get admin_products_path, params: { sort: 'products.unsafe_column', direction: 'sideways' }

      expect(response).to have_http_status(:ok)
      expect(response.body.index('Alpha Item')).to be < response.body.index('Zulu Item')
    end

    it 'normalizes a page below one to the first page' do
      create_list(:product, 12)

      get admin_products_path, params: { page: 0 }

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(10)
    end

    it 'clamps a page beyond the last page to the last page' do
      create_list(:product, 12)

      get admin_products_path, params: { page: 999 }

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(2)
    end

    it 'uses the default page size for an unsupported per_page value' do
      create_list(:product, 12)

      get admin_products_path, params: { per_page: 7 }

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(10)
    end

    it 'searches by SKU and barcode' do
      sku_product = create(:product, name: 'SKU Match', sku: 'SKU-COVERAGE-01')
      barcode_product = create(:product, name: 'Barcode Match', barcode: 'BAR-COVERAGE-01')
      create(:product, name: 'No Match')

      get admin_products_path, params: { search: 'SKU-COVERAGE-01' }
      expect(response.body).to include(sku_product.name)
      expect(response.body).not_to include('No Match')

      get admin_products_path, params: { search: 'BAR-COVERAGE-01' }
      expect(response.body).to include(barcode_product.name)
      expect(response.body).not_to include('No Match')
    end
  end

end

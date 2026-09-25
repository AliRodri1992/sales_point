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

    it 'appears in user.notifications even when the product is soft-deleted' do
      delete admin_product_path(product, format: :turbo_stream)

      notification = user.notifications.find_by(
        noticed_events: { record_type: 'Product', record_id: product.id }
      )
      expect(notification).to be_present
      expect(notification.params[:action]).to eq('destroyed')
    end
  end
end

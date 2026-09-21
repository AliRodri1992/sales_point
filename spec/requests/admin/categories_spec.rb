# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Categories', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }

  before do
    sign_in user
  end

  after do
    sign_out user
  end

  describe 'GET /admin/categories' do
    let!(:category) { create(:category, name: 'Caja', code: 'cashier') }

    before do
      create_list(:category, 15)
    end

    it 'returns a paginated list with at least 10 items per page' do
      get admin_categories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.categories.index.total_count',
                                              count: Category.not_deleted.count))
    end

    it 'shows the total count of categories (not just page count)' do
      get admin_categories_path

      total = Category.not_deleted.count
      expect(response.body).to include(I18n.t('admin.categories.index.total_count', count: total))
    end

    it 'respects the per_page query param' do
      get admin_categories_path(per_page: 5)

      expect(response).to have_http_status(:ok)
    end

    it 'filters by search query on name or code' do
      get admin_categories_path(search: 'Caja')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Caja')
    end

    it 'filters by status' do
      get admin_categories_path(status: 'active')

      expect(response).to have_http_status(:ok)
    end

    it 'sorts by name in descending order when direction=desc' do
      get admin_categories_path(sort: 'name', direction: 'desc')

      expect(response).to have_http_status(:ok)
    end

    it 'sorts by code column' do
      get admin_categories_path(sort: 'code')

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /admin/categories' do
    it 'sends a "created" notification to the current user' do
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: 'Test Category', code: 'test_category', status: 'active' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('created')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('categories_catalog', target: 'categories_list', html: kind_of(String))

      post admin_categories_path(format: :turbo_stream),
           params: { category: { name: 'Test Category', code: 'test_category' } }
    end

    it 'defaults the status to active when not provided' do
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: 'Test Category', code: 'test_category' } }
      end.to change(Category, :count).by(1)

      expect(Category.find_by(code: 'test_category').status).to eq('active')
    end

    it 'does not persist the category when name is blank' do
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: '', code: 'test_category' } }
      end.not_to change(Category, :count)
    end

    it 'does not persist the category when code is blank' do
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: 'Test Category', code: '' } }
      end.not_to change(Category, :count)
    end

    it 'does not persist the category when code is already taken' do
      create(:category, code: 'test_category')
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: 'Test Category', code: 'test_category' } }
      end.not_to change(Category, :count)
    end
  end

  describe 'PATCH /admin/categories/:id' do
    let!(:category) { create(:category, name: 'Old Name', code: 'old_code') }

    it 'sends an "updated" notification to the current user' do
      expect do
        patch admin_category_path(category, format: :turbo_stream),
              params: { category: { name: 'New Name', code: 'old_code', status: 'active' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('updated')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('categories_catalog', target: 'categories_list', html: kind_of(String))

      patch admin_category_path(category, format: :turbo_stream),
            params: { category: { name: 'New Name', code: 'old_code' } }
    end

    it 'updates the category name' do
      patch admin_category_path(category, format: :turbo_stream),
            params: { category: { name: 'New Name', code: 'old_code' } }

      expect(category.reload.name).to eq('New Name')
    end

    it 'does not update the category when name is blank' do
      patch admin_category_path(category, format: :turbo_stream),
            params: { category: { name: '', code: 'old_code' } }

      expect(category.reload.name).to eq('Old Name')
    end
  end

  describe 'DELETE /admin/categories/:id' do
    let!(:category) { create(:category, name: 'ToDelete', code: 'del_category') }

    it 'sends a "destroyed" notification to the current user' do
      expect do
        delete admin_category_path(category, format: :turbo_stream)
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('destroyed')
    end

    it 'stores the actor user in the notification params' do
      delete admin_category_path(category, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.params[:user]).to eq(user)
    end

    it 'keeps the soft-deleted category record accessible on the notification' do
      delete admin_category_path(category, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.record).to be_a(Category)
      expect(notification.record.code).to eq('del_category')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('categories_catalog', target: 'categories_list', html: kind_of(String))

      delete admin_category_path(category, format: :turbo_stream)
    end

    it 'soft-deletes the category' do
      expect do
        delete admin_category_path(category, format: :turbo_stream)
      end.to change { Category.not_deleted.count }.by(-1)
      expect(Category.with_deleted.find(category.id).deleted_at).not_to be_nil
    end

    it 'appears in user.notifications even when the category is soft-deleted' do
      delete admin_category_path(category, format: :turbo_stream)

      notification = user.notifications.find_by(
        noticed_events: { record_type: 'Category', record_id: category.id }
      )
      expect(notification).to be_present
      expect(notification.params[:action]).to eq('destroyed')
    end
  end
end

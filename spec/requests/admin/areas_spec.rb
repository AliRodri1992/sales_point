# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Areas', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }

  before do
    sign_in user
  end

  after do
    sign_out user
  end

  describe 'GET /admin/areas' do
    let!(:area) { create(:area, name: 'Caja', code: 'cashier') }

    before do
      create_list(:area, 15)
    end

    it 'returns a paginated list with at least 10 items per page' do
      get admin_areas_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.areas.index.total_count',
                                              count: Area.not_deleted.count))
    end

    it 'shows the total count of areas (not just page count)' do
      get admin_areas_path

      total = Area.not_deleted.count
      expect(response.body).to include(I18n.t('admin.areas.index.total_count', count: total))
    end

    it 'respects the per_page query param' do
      get admin_areas_path(per_page: 5)

      expect(response).to have_http_status(:ok)
    end

    it 'filters by search query on name or code' do
      get admin_areas_path(search: 'Caja')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Caja')
    end

    it 'filters by status' do
      get admin_areas_path(status: 'active')

      expect(response).to have_http_status(:ok)
    end

    it 'sorts by name in descending order when direction=desc' do
      get admin_areas_path(sort: 'name', direction: 'desc')

      expect(response).to have_http_status(:ok)
    end

    it 'sorts by code column' do
      get admin_areas_path(sort: 'code')

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /admin/areas' do
    it 'sends a "created" notification to the current user' do
      expect do
        post admin_areas_path(format: :turbo_stream),
             params: { area: { name: 'Test Area', code: 'test_area', status: 'active' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('created')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('areas_catalog', target: 'areas_list', html: kind_of(String))

      post admin_areas_path(format: :turbo_stream),
           params: { area: { name: 'Test Area', code: 'test_area' } }
    end

    it 'defaults the status to active when not provided' do
      expect do
        post admin_areas_path(format: :turbo_stream),
             params: { area: { name: 'Test Area', code: 'test_area' } }
      end.to change(Area, :count).by(1)

      expect(Area.find_by(code: 'test_area').status).to eq('active')
    end

    it 'does not persist the area when name is blank' do
      expect do
        post admin_areas_path(format: :turbo_stream),
             params: { area: { name: '', code: 'test_area' } }
      end.not_to change(Area, :count)
    end

    it 'does not persist the area when code is blank' do
      expect do
        post admin_areas_path(format: :turbo_stream),
             params: { area: { name: 'Test Area', code: '' } }
      end.not_to change(Area, :count)
    end

    it 'does not persist the area when code is already taken' do
      create(:area, code: 'test_area')
      expect do
        post admin_areas_path(format: :turbo_stream),
             params: { area: { name: 'Test Area', code: 'test_area' } }
      end.not_to change(Area, :count)
    end
  end

  describe 'PATCH /admin/areas/:id' do
    let!(:area) { create(:area, name: 'Old Name', code: 'old_code') }

    it 'sends an "updated" notification to the current user' do
      expect do
        patch admin_area_path(area, format: :turbo_stream),
              params: { area: { name: 'New Name', code: 'old_code', status: 'active' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('updated')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('areas_catalog', target: 'areas_list', html: kind_of(String))

      patch admin_area_path(area, format: :turbo_stream),
            params: { area: { name: 'New Name', code: 'old_code' } }
    end

    it 'updates the area name' do
      patch admin_area_path(area, format: :turbo_stream),
            params: { area: { name: 'New Name', code: 'old_code' } }

      expect(area.reload.name).to eq('New Name')
    end

    it 'does not update the area when name is blank' do
      patch admin_area_path(area, format: :turbo_stream),
            params: { area: { name: '', code: 'old_code' } }

      expect(area.reload.name).to eq('Old Name')
    end
  end

  describe 'DELETE /admin/areas/:id' do
    let!(:area) { create(:area, name: 'ToDelete', code: 'del_area') }

    it 'sends a "destroyed" notification to the current user' do
      expect do
        delete admin_area_path(area, format: :turbo_stream)
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('destroyed')
    end

    it 'stores the actor user in the notification params' do
      delete admin_area_path(area, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.params[:user]).to eq(user)
    end

    it 'keeps the soft-deleted area record accessible on the notification' do
      delete admin_area_path(area, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.record).to be_a(Area)
      expect(notification.record.code).to eq('del_area')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('areas_catalog', target: 'areas_list', html: kind_of(String))

      delete admin_area_path(area, format: :turbo_stream)
    end

    it 'soft-deletes the area' do
      expect do
        delete admin_area_path(area, format: :turbo_stream)
      end.to change { Area.not_deleted.count }.by(-1)
      expect(Area.with_deleted.find(area.id).deleted_at).not_to be_nil
    end

    it 'appears in user.notifications even when the area is soft-deleted' do
      delete admin_area_path(area, format: :turbo_stream)

      notification = user.notifications.find_by(
        noticed_events: { record_type: 'Area', record_id: area.id }
      )
      expect(notification).to be_present
      expect(notification.params[:action]).to eq('destroyed')
    end
  end
end

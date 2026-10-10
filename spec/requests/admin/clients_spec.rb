require 'rails_helper'

RSpec.describe 'Admin clients', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'authentication' do
    it 'requires an authenticated user' do
      sign_out user
      get admin_clients_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET /admin/clients' do
    it 'lists non-deleted clients' do
      create(:client, name: 'Visible Client')
      create(:client, :deleted, name: 'Deleted Client')

      get admin_clients_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Visible Client')
      expect(response.body).not_to include('Deleted Client')
    end

    it 'filters clients by search term' do
      matching = create(:client, name: 'Acme Retail')
      create(:client, name: 'Other Business')

      get admin_clients_path, params: { search: 'Acme' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matching.name)
      expect(response.body).not_to include('Other Business')
    end

    it 'filters clients by status' do
      create(:client, name: 'Active Client', status: :active)
      create(:client, name: 'Inactive Client', status: :inactive)

      get admin_clients_path, params: { status: 'inactive' }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Active Client')
      expect(response.body).to include('Inactive Client')
    end

    it 'sorts clients by name' do
      create(:client, name: 'Zulu Client')
      create(:client, name: 'Alpha Client')

      get admin_clients_path, params: { sort: 'name', direction: 'asc' }

      rows = Nokogiri::HTML(response.body).css('tbody tr')
      names = rows.map { |row| row.css('td')[1].text.strip }

      expect(names.first).to eq('Alpha Client')
      expect(names.last).to eq('Zulu Client')
    end

    it 'paginates clients' do
      create_list(:client, 11)

      get admin_clients_path, params: { per_page: 5 }

      rows = Nokogiri::HTML(response.body).css('tbody tr')

      expect(rows.size).to eq(5)
      expect(response.body).to include('client-pagination-form')
    end
  end

  describe 'GET /admin/clients/:id' do
    it 'shows a client' do
      client = create(:client, name: 'Customer Details')

      get admin_client_path(client)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Customer Details')
      expect(response.body).to include(client.code)
    end

    it 'does not show deleted clients' do
      client = create(:client, :deleted)

      get admin_client_path(client)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /admin/clients/new' do
    it 'renders the new client form' do
      get new_admin_client_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.clients.new.title'))
    end
  end

  describe 'POST /admin/clients' do
    it 'creates a client' do
      attributes = attributes_for(:client)

      expect do
        post admin_clients_path, params: { client: attributes }
      end.to change(Client, :count).by(1)

      expect(response).to redirect_to(admin_clients_path)
    end

    it 'renders validation errors' do
      post admin_clients_path, params: { client: { code: '', name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /admin/clients/:id/edit' do
    it 'renders the edit client form' do
      client = create(:client)

      get edit_admin_client_path(client)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.clients.edit.title', name: client.name))
    end
  end

  describe 'PATCH /admin/clients/:id' do
    it 'updates a client' do
      client = create(:client, name: 'Before Update')

      patch admin_client_path(client), params: { client: { name: 'After Update' } }

      expect(response).to redirect_to(admin_clients_path)
      expect(client.reload.name).to eq('After Update')
    end

    it 'renders validation errors' do
      client = create(:client)

      patch admin_client_path(client), params: { client: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE /admin/clients/:id' do
    it 'soft deletes a client' do
      client = create(:client)

      expect do
        delete admin_client_path(client)
      end.to change { client.reload.deleted_at }.from(nil).to(be_present)

      expect(response).to redirect_to(admin_clients_path)
      expect(Client.unscoped.count).to eq(1)
    end
  end

  describe 'UI elements' do
    it 'shows back button with arrow icon in show view' do
      client = create(:client, name: 'Test Customer')

      get admin_client_path(client)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Volver a clientes')
      expect(response.body).to include('data-turbo-frame="_top"')
    end

    it 'shows back button in new form' do
      get new_admin_client_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Volver a clientes')
      expect(response.body).to include('data-turbo-frame="_top"')
    end

    it 'shows back button in edit form' do
      client = create(:client)

      get edit_admin_client_path(client)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Volver a clientes')
      expect(response.body).to include('data-turbo-frame="_top"')
    end

    it 'renders form in styled container' do
      get new_admin_client_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('max-w-6xl')
      expect(response.body).to include('rounded-xl')
      expect(response.body).to include('border border-slate-200')
    end

    it 'renders breadcrumbs on index page' do
      get admin_clients_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Clientes')
    end
  end

  describe 'duplicate database constraints' do
    it 'renders the new form when the create hits a unique index' do
      allow_any_instance_of(Client).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      post admin_clients_path, params: { client: attributes_for(:client) }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('admin.clients.new.title'))
      expect(response.body).to include(I18n.t('admin.clients.errors.duplicate'))
    end

    it 'renders the edit form when the update hits a unique index' do
      client = create(:client)
      allow_any_instance_of(Client).to receive(:update).and_raise(ActiveRecord::RecordNotUnique)

      patch admin_client_path(client), params: { client: { name: 'Conflicting Client' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('admin.clients.edit.title', name: client.name))
      expect(response.body).to include(I18n.t('admin.clients.errors.duplicate'))
    end
  end
end

require 'rails_helper'

RSpec.describe 'Admin clients', type: :request do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }

  before do
    create(:organization_membership, user:, organization:)
    role = create(:system_role, :system)
    create(:user_role, user:, system_role: role)
    GranularPermissionCatalog.sync!
    codes = GranularPermissionCatalog::ACTIONS.map { |action| "customers.#{action}" }
    Permission.where(code: codes).find_each do |permission|
      create(:system_role_permission, system_role: role, permission:)
    end
    sign_in user
  end

  describe 'authentication' do
    it 'requires an authenticated user' do
      sign_out user
      get admin_clients_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  include SqlQueryRecorder

  describe 'GET /admin/clients' do
    it 'fetches phones once rather than once for each client', :n_plus_one do
      create_list(:client, 11, organization:)
      statements = recorded_sql_queries { get admin_clients_path }

      expect(response).to have_http_status(:ok)
      expect(statements.grep(/FROM "?phones"?/i).size).to be <= 2
    end

    it 'lists non-deleted clients' do
      create(:client, organization:, name: 'Visible Client')
      create(:client, organization:, :deleted, organization:, name: 'Deleted Client')

      get admin_clients_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Visible Client')
      expect(response.body).not_to include('Deleted Client')
    end

    it 'filters clients by search term' do
      matching = create(:client, organization:, name: 'Acme Retail')
      create(:client, organization:, name: 'Other Business')

      get admin_clients_path, params: { search: 'Acme' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matching.name)
      expect(response.body).not_to include('Other Business')
    end

    it 'filters clients by status' do
      create(:client, organization:, name: 'Active Client', status: :active)
      create(:client, organization:, name: 'Inactive Client', status: :inactive)

      get admin_clients_path, params: { status: 'inactive' }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Active Client')
      expect(response.body).to include('Inactive Client')
    end

    it 'sorts clients by name' do
      create(:client, organization:, name: 'Zulu Client')
      create(:client, organization:, name: 'Alpha Client')

      get admin_clients_path, params: { sort: 'name', direction: 'asc' }

      rows = Nokogiri::HTML(response.body).css('tbody tr')
      names = rows.map { |row| row.at_css('td:nth-child(2) .font-semibold').text.strip }

      expect(names.first).to eq('Alpha Client')
      expect(names.last).to eq('Zulu Client')
    end

    it 'paginates clients' do
      create_list(:client, 11, organization:)

      get admin_clients_path, params: { per_page: 5 }

      rows = Nokogiri::HTML(response.body).css('tbody tr')

      expect(rows.size).to eq(5)
      expect(response.body).to include('client-pagination-form')
    end
  end

  describe 'Redesign and advanced filters' do
    it 'displays overview, fiscal filter and the new form sections' do
      get admin_clients_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.clients.workspace.filters_title'), 'clients-fiscal-regime')

      get new_admin_client_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('client-identity-heading', 'client-contact-heading',
                                       'client-fiscal-heading', 'client-commercial-heading')
    end

    it 'filters by credit, tax identifier and fiscal regime together' do
      regime = create(:sat_fiscal_regime)
      create(:client, organization:, name: 'Matched Buyer', credit_limit: 120, sat_fiscal_regime: regime,
                      rfc: 'XAXX010101001')
      create(:client, organization:, name: 'No Credit Buyer', credit_limit: 0, sat_fiscal_regime: regime,
                      rfc: 'XAXX010101002')
      get admin_clients_path, params: {
        credit: 'yes', rfc: 'yes', sat_fiscal_regime_id: regime.id
      }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Matched Buyer')
      expect(response.body).not_to include('No Credit Buyer')
    end

    it 'treats wildcard search as literal and does not accept arbitrary statuses' do
      create(:client, organization:, name: 'Ordinary Buyer')
      get admin_clients_path, params: { search: '%' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.clients.workspace.no_results'))

      get admin_clients_path, params: { status: "invalid' OR 1=1--" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Ordinary Buyer')
    end

    it 'renders model errors beneath their inputs without HTML5 required fields' do
      post admin_clients_path, params: { client: { code: 'MYCODE', name: '' } }
      expect(response).to have_http_status(:unprocessable_content)
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css('#client_name_error')).to be_present
      expect(doc.at_css('#client_name')['aria-invalid']).to eq('true')
      expect(doc.at_css('#client_code')['value']).to eq('MYCODE')
      expect(doc.at_css('#client_name')['required']).to be_nil
    end

    it 'keeps search and status filters grouped in SQL' do
      create(:client, organization:, name: 'Matched Active', status: :active)
      create(:client, organization:, name: 'Matched Inactive', status: :inactive)
      get admin_clients_path, params: { search: 'Matched', status: 'active' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Matched Active')
      expect(response.body).not_to include('Matched Inactive')
    end

    it 'persists customer notes and shows them in the record details' do
      post admin_clients_path, params: {
        client: { code: 'NOTED-CLI', name: 'Noted Customer',
                  credit_limit: 0, notes: 'Contact on Fridays' }
      }
      expect(response).to redirect_to(admin_clients_path)
      client = Client.find_by!(code: 'NOTED-CLI')
      expect(client.notes).to eq('Contact on Fridays')

      get admin_client_path(client)
      expect(response.body).to include('Contact on Fridays')
    end

    it 'renders compact filters and field errors within the new design' do
      get admin_clients_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('clients-search', 'clients-credit', 'clients-rfc', 'bg-emerald-700')
      post admin_clients_path, params: { client: { name: '', code: '' } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('client_code_error', 'client_name_error')
    end

    it 'preserves an archived fiscal regime on an existing customer edit' do
      regime = create(:sat_fiscal_regime, valid_from: 30.days.ago, valid_to: Date.tomorrow)
      client = create(:client, organization:, sat_fiscal_regime: regime)
      regime.update!(valid_to: Date.yesterday)
      get edit_admin_client_path(client)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(regime.code)
    end
  end

  describe 'GET /admin/clients/:id' do
    it 'shows a client' do
      client = create(:client, organization:, name: 'Customer Details')

      get admin_client_path(client)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Customer Details')
      expect(response.body).to include(client.code)
    end

    it 'does not show deleted clients' do
      client = create(:client, organization:, :deleted)

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
      expect(response.body).to include(client.name)
    end
  end

  describe 'PATCH /admin/clients/:id' do
    it 'updates a client' do
      client = create(:client, organization:, name: 'Before Update')

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
    it 'updates the table and counters after a Turbo Stream soft deletion' do
      customer = create(:client)
      delete admin_client_path(customer), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('clients_list', 'clients_stats')
      expect(customer.reload.deleted_at).to be_present
    end

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
      client = create(:client, organization:, name: 'Test Customer')

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
      allow_any_instance_of(Client).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      patch admin_client_path(client), params: { client: { name: 'Conflicting Client' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('admin.clients.edit.title', name: 'Conflicting Client'))
      expect(response.body).to include(I18n.t('admin.clients.errors.duplicate'))
    end
  end
end

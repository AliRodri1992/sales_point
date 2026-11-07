require 'rails_helper'

RSpec.describe 'Admin::Branches', type: :request do
  let(:system_admin_role) { create(:system_role, :system, code: 'administrator') }
  let(:branch_role) { create(:system_role, :branch) }
  let(:admin_user) { create(:user, system_roles: [system_admin_role]) }

  let(:country) { create(:country, iso_alpha2: 'MX') }

  let(:organization) { create(:organization) }

  before do
    create(:organization_membership, user: admin_user, organization:)
    sign_in admin_user
  end

  include SqlQueryRecorder


  describe 'GET /admin/branches/postal_suggestions' do
    it 'returns Mexican postal suggestions using the existing supplier lookup' do
      allow_any_instance_of(Suppliers::MexicanPostalLookup).to receive(:call).and_return(
        { found: true, state: 'Estado de México', municipality: 'Cuautitlán',
          neighborhoods: ['Centro'] }
      )

      get postal_suggestions_admin_branches_path, params: { country: 'MX', postal_code: '54800' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('found' => true, 'municipality' => 'Cuautitlán')
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'rejects invalid postal lookup parameters' do
      get postal_suggestions_admin_branches_path, params: { country: 'MX', postal_code: 'ABC' }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'renders postal assistance and country-specific address fields in the new branch form' do
      get new_admin_branch_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('supplier-postal-assist', 'supplier-country-fields',
                                       'branch-neighborhoods', 'postal_suggestions')
    end
  end

  describe 'GET /admin/branches' do
    it 'loads all visible branch phones in a batch', :n_plus_one do
      11.times { |index| create(:branch, organization:, name: "Performance Branch #{index}") }
      statements = recorded_sql_queries { get admin_branches_path }

      expect(response).to have_http_status(:ok)
      expect(statements.grep(/FROM "?phones"?/i).size).to be <= 2
    end

    before { Branch.unscoped.delete_all }

    def listed_branch_names
      Nokogiri::HTML(response.body).css('.branch-table tbody .branch-name').map(&:text)
    end

    it 'renders the branches page' do
      create(:branch, organization:, name: 'Sucursal Centro')

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Centro')
    end

    it 'keeps page-size preferences accessible for 9 branches' do
      Array.new(9) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('table-per-page-branches')
      expect(response.body).to include('Sucursal 9')
    end

    it 'keeps page-size preferences accessible for exactly 10 branches' do
      Array.new(10) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('table-per-page-branches')
      expect(response.body).to include('Sucursal 10')
    end

    it 'paginates branches with 10 records by default when more than 10 exist' do
      Array.new(11) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('table-per-page-branches')
      expect(listed_branch_names.size).to eq(10)
      expect(response.body).to include('aria-current="page">1</span>')

      get admin_branches_path, params: { page: 2 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(1)
    end
    it 'allows selecting 5 records per page' do
      Array.new(11) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 5 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(5)

      get admin_branches_path, params: { per_page: 5, page: 3 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(1)
    end
    it 'allows selecting 15 records per page' do
      Array.new(16) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 15 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(15)

      get admin_branches_path, params: { per_page: 15, page: 2 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(1)
    end
    it 'respects explicit page size when exactly 10 branches exist' do
      Array.new(10) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 5 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(5)
      expect(response.body).to include('table-per-page-branches')

      get admin_branches_path, params: { per_page: 5, page: 2 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(5)
    end
    it 'sorts branches by name in ascending order' do
      create(:branch, organization:, name: 'Sucursal Norte')
      create(:branch, organization:, name: 'Sucursal Centro')

      get admin_branches_path, params: { sort: 'branches.name', direction: 'asc' }

      expect(response).to have_http_status(:ok)
      expect(response.body.index('Sucursal Centro')).to be < response.body.index('Sucursal Norte')
    end

    it 'sorts branches by name in descending order' do
      create(:branch, organization:, name: 'Sucursal Centro')
      create(:branch, organization:, name: 'Sucursal Norte')

      get admin_branches_path, params: { sort: 'branches.name', direction: 'desc' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Norte')
      expect(response.body).to include('Sucursal Centro')
    end

    it 'sorts branches by address street' do
      center = create(:branch, organization:, name: 'Sucursal Centro')
      north = create(:branch, organization:, name: 'Sucursal Norte')
      center.address.update!(street: 'Reforma')
      north.address.update!(street: 'Zaragoza')

      get admin_branches_path, params: { sort: 'addresses.street', direction: 'asc' }

      expect(response).to have_http_status(:ok)
      expect(response.body.index('Sucursal Centro')).to be < response.body.index('Sucursal Norte')
    end

    it 'does not expose branches outside the current user access' do
      sign_out admin_user
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      assigned_branch = create(:branch, organization:, name: 'Sucursal Asignada')
      create(:branch, organization:, name: 'Sucursal Restringida')
      create(:user_role, user: branch_user, system_role: branch_role, branch: assigned_branch)
      sign_in branch_user

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Asignada')
      expect(response.body).not_to include('Sucursal Restringida')
    end
  end

  describe 'PATCH /admin/branches/:id/select' do
    it 'selects an active branch belonging to the current organization' do
      branch = create(:branch, organization:, status: true)

      patch select_admin_branch_path(branch)

      expect(response).to redirect_to(admin_dashboard_path)
    end

    it 'does not select a branch outside the current organization' do
      branch = create(:branch, organization: create(:organization), status: true)

      patch select_admin_branch_path(branch)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /admin/branches/new' do
    it 'renders the new branch screen without a modal for system administrators' do
      get new_admin_branch_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Nueva sucursal')
      expect(response.body).to include('href="/admin/branches"')
      expect(response.body).to include('action="/admin/branches"')
      expect(response.body).not_to include('data-branches-target="modal"')
    end

    it 'forbids branch-only users from creating branches' do
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role,
                         branch: create(:branch, organization:, name: "Sucursal #{Branch.count + 1}"))
      sign_out admin_user
      sign_in branch_user

      get new_admin_branch_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /admin/branches/:id' do
    it 'shows an assigned branch to a branch user' do
      branch = create(:branch, organization:, name: 'Sucursal Centro')
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role, branch:)
      sign_out admin_user
      sign_in branch_user

      get admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Centro')
      expect(response.body).to include('href="/admin/branches"')
      expect(response.body).to include('Av. Reforma')
    end

    it 'does not expose another branch to a branch user' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}")
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role,
                         branch: create(:branch, organization:, name: "Sucursal #{Branch.count + 1}"))
      sign_out admin_user
      sign_in branch_user

      get admin_branch_path(branch)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /admin/branches' do
    it 'shows validation messages below the corresponding fields' do
      post admin_branches_path, params: {
        branch: {
          name: '',
          phones_attributes: [{ number: '5551234567', country_code: 'MX', kind: 'mobile', primary: true }],
          status: true,
          address_attributes: {
            street: 'Av. Reforma',
            exterior_number: '100',
            city: 'Cuautitlán',
            state: 'Estado de México',
            country_id: country.id,
            postal_code: ''
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Nombre no puede estar vacío')
      expect(response.body).to include('Código postal no puede estar vacío')
    end

    it 'creates a branch, address and notification' do
      # New phones inherit the branch organization and require an active one.

      expect do
        post admin_branches_path, params: {
          branch: {
            name: 'Sucursal Centro',
            phones_attributes: [{ number: '5551234567', country_code: 'MX', kind: 'mobile', primary: true }],
            status: true,
            address_attributes: {
              street: 'Av. Reforma',
              exterior_number: '100',
              neighborhood: 'Centro',
              city: 'Cuautitlán',
              state: 'Estado de México',
              country_id: country.id,
              postal_code: '54800'
            }
          }
        }
      end.to change(Branch, :count).by(1)
                                   .and change(Address, :count).by(1)
                                                               .and change(Noticed::Notification, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
      expect(flash[:swal_message]).to eq(I18n.t('admin.branches.created'))
      notification = admin_user.notifications.last
      expect(notification.event.params[:action]).to eq('created')
      expect(notification.event.params[:user]).to eq(admin_user)
      expect(notification.event.message).to eq(
        I18n.t('admin.shared.notifications.branch.created',
               name: 'Sucursal Centro',
               user: admin_user.display_name)
      )
    end

    it 'forbids branch-only users from creating branches' do
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role,
                         branch: create(:branch, organization:, name: "Sucursal #{Branch.count + 1}"))
      sign_out admin_user
      sign_in branch_user

      post admin_branches_path, params: { branch: { name: 'No autorizada', status: true } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /admin/branches/:id/edit' do
    it 'renders the edit branch screen for a system administrator' do
      branch = create(:branch, organization:, name: 'Sucursal Centro')

      get edit_admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include('href="/admin/branches"')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
      expect(response.body).not_to include('data-branches-target="modal"')
    end

    it 'forbids branch-only users from editing branches' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}")
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role, branch:)
      sign_out admin_user
      sign_in branch_user

      get edit_admin_branch_path(branch)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /admin/branches/:id' do
    it 'updates a branch and creates a notification' do
      branch = create(:branch, organization:, name: 'Sucursal Centro')

      expect do
        patch admin_branch_path(branch), params: {
          branch: {
            name: 'Sucursal Norte',
            address_attributes: { id: branch.address.id, city: 'Tlalnepantla' }
          }
        }
      end.to change(Noticed::Notification, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
      expect(flash[:swal_message]).to eq(I18n.t('admin.branches.updated'))
      expect(branch.reload.name).to eq('Sucursal Norte')
      expect(branch.address.reload.city).to eq('Tlalnepantla')

      notification = admin_user.notifications.last
      expect(notification.event.params[:action]).to eq('updated')
      expect(notification.event.params[:user]).to eq(admin_user)
      expect(notification.event.message).to eq(
        I18n.t('admin.shared.notifications.branch.updated',
               name: 'Sucursal Norte',
               user: admin_user.display_name)
      )
    end

    it 'forbids branch-only users from updating branches' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}")
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role, branch:)
      sign_out admin_user
      sign_in branch_user

      patch admin_branch_path(branch), params: { branch: { name: 'No autorizada' } }

      expect(response).to have_http_status(:forbidden)
      expect(branch.reload.name).not_to eq('No autorizada')
    end
  end

  describe 'DELETE /admin/branches/:id' do
    it 'soft deletes a branch and creates a notification with the actor' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}")

      expect do
        delete admin_branch_path(branch)
      end.to change(Noticed::Notification, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
      expect(flash[:swal_message]).to eq(I18n.t('admin.branches.destroyed'))
      expect(branch.reload.deleted_at).to be_present

      notification = admin_user.notifications.last
      expect(notification.event.record).to eq(branch)
      expect(notification.event.params[:action]).to eq('destroyed')
      expect(notification.event.params[:user]).to eq(admin_user)
      expect(notification.event.message).to eq(
        I18n.t('admin.shared.notifications.branch.destroyed',
               name: branch.name,
               user: admin_user.display_name)
      )
    end

    it 'updates the list and shows a success toast for Turbo requests' do
      branch = create(:branch, organization:, name: 'Sucursal Centro')

      delete admin_branch_path(branch), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('branches_list')
      expect(response.body).not_to include('Sucursal Centro')
      expect(response.body).to include(I18n.t('admin.branches.destroyed'))
      expect(branch.reload.deleted_at).to be_present
    end

    it 'forbids branch-only users from deleting branches' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}")
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role, branch:)
      sign_out admin_user
      sign_in branch_user

      delete admin_branch_path(branch)

      expect(response).to have_http_status(:forbidden)
      expect(branch.reload.deleted_at).to be_nil
    end
  end

  describe 'PATCH /admin/branches/:id validation failures' do
    it 're-renders the edit form and preserves the branch when validation fails' do
      branch = create(:branch, organization:, name: 'Unchanged Branch')

      patch admin_branch_path(branch), params: { branch: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
      expect(branch.reload.name).to eq('Unchanged Branch')
    end

    it 'builds an address when an invalid update targets a branch without one' do
      branch = create(:branch, :without_address, organization:)

      patch admin_branch_path(branch), params: { branch: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include('address_attributes')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
    end
  end
end

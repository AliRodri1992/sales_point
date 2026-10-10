require 'rails_helper'

RSpec.describe 'Admin::Branches', type: :request do
  let(:system_admin_role) { create(:system_role, :system, code: 'administrator') }
  let(:branch_role) { create(:system_role, :branch) }
  let(:admin_user) { create(:user, system_roles: [system_admin_role]) }

  before { sign_in admin_user }

  describe 'GET /admin/branches' do
    before { Branch.unscoped.delete_all }

    it 'renders the branches page' do
      create(:branch, name: 'Sucursal Centro')

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Centro')
    end

    it 'does not render pagination controls for 9 branches' do
      Array.new(9) { |index| create(:branch, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('branches-per-page')
      expect(response.body).to include('Sucursal 9')
    end

    it 'does not render pagination controls for exactly 10 branches' do
      Array.new(10) { |index| create(:branch, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('branches-per-page')
      expect(response.body).to include('Sucursal 10')
    end

    it 'paginates branches with 10 records by default when more than 10 exist' do
      Array.new(11) { |index| create(:branch, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('branches-per-page')
      expect(response.body).to include('Sucursal 1')
      expect(response.body).to include('Sucursal 10')
      # Verify pagination is showing page 1
      expect(response.body).to include('aria-current="page">1</span>')
    end

    it 'allows selecting 5 records per page' do
      Array.new(11) { |index| create(:branch, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 5 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal 1')
    end

    it 'allows selecting 15 records per page' do
      Array.new(16) { |index| create(:branch, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 15 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal 1')
    end

    it 'ignores a smaller per-page value when exactly 10 branches exist' do
      Array.new(10) { |index| create(:branch, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 5 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal 10')
      expect(response.body).not_to include('branches-per-page')
    end

    it 'sorts branches by name in ascending order' do
      create(:branch, name: 'Sucursal Norte')
      create(:branch, name: 'Sucursal Centro')

      get admin_branches_path, params: { sort: 'branches.name', direction: 'asc' }

      expect(response).to have_http_status(:ok)
      expect(response.body.index('Sucursal Centro')).to be < response.body.index('Sucursal Norte')
    end

    it 'sorts branches by name in descending order' do
      create(:branch, name: 'Sucursal Centro')
      create(:branch, name: 'Sucursal Norte')

      get admin_branches_path, params: { sort: 'branches.name', direction: 'desc' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Norte')
      expect(response.body).to include('Sucursal Centro')
    end

    it 'sorts branches by address street' do
      center = create(:branch, name: 'Sucursal Centro')
      north = create(:branch, name: 'Sucursal Norte')
      center.address.update!(street: 'Reforma')
      north.address.update!(street: 'Zaragoza')

      get admin_branches_path, params: { sort: 'addresses.street', direction: 'asc' }

      expect(response).to have_http_status(:ok)
      expect(response.body.index('Sucursal Centro')).to be < response.body.index('Sucursal Norte')
    end

    it 'does not expose branches outside the current user access' do
      sign_out admin_user
      branch_user = create(:user)
      assigned_branch = create(:branch, name: 'Sucursal Asignada')
      create(:branch, name: 'Sucursal Restringida')
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
      organization = create(:organization)
      create(:organization_membership, organization:, user: admin_user)
      branch = create(:branch, organization:, status: true)

      patch select_admin_branch_path(branch)

      expect(response).to redirect_to(admin_dashboard_path)
    end

    it 'does not select a branch outside the current organization' do
      organization = create(:organization)
      create(:organization_membership, organization:, user: admin_user)
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
      create(:user_role, user: branch_user, system_role: branch_role, branch: create(:branch))
      sign_out admin_user
      sign_in branch_user

      get new_admin_branch_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /admin/branches/:id' do
    it 'shows an assigned branch to a branch user' do
      branch = create(:branch, name: 'Sucursal Centro')
      branch_user = create(:user)
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
      branch = create(:branch)
      branch_user = create(:user)
      create(:user_role, user: branch_user, system_role: branch_role, branch: create(:branch))
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
          phone: '5551234567',
          status: true,
          address_attributes: {
            street: 'Av. Reforma',
            exterior_number: '100',
            city: 'Cuautitlán',
            state: 'Estado de México',
            country: 'MX',
            postal_code: ''
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Nombre no puede estar vacío')
      expect(response.body).to include('Código postal no puede estar vacío')
    end

    it 'creates a branch, address and notification' do
      expect do
        post admin_branches_path, params: {
          branch: {
            name: 'Sucursal Centro',
            phone: '5551234567',
            status: true,
            address_attributes: {
              street: 'Av. Reforma',
              exterior_number: '100',
              neighborhood: 'Centro',
              city: 'Cuautitlán',
              state: 'Estado de México',
              country: 'MX',
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
      create(:user_role, user: branch_user, system_role: branch_role, branch: create(:branch))
      sign_out admin_user
      sign_in branch_user

      post admin_branches_path, params: { branch: { name: 'No autorizada', status: true } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /admin/branches/:id/edit' do
    it 'renders the edit branch screen for a system administrator' do
      branch = create(:branch, name: 'Sucursal Centro')

      get edit_admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include('href="/admin/branches"')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
      expect(response.body).not_to include('data-branches-target="modal"')
    end

    it 'forbids branch-only users from editing branches' do
      branch = create(:branch)
      branch_user = create(:user)
      create(:user_role, user: branch_user, system_role: branch_role, branch:)
      sign_out admin_user
      sign_in branch_user

      get edit_admin_branch_path(branch)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /admin/branches/:id' do
    it 'updates a branch and creates a notification' do
      branch = create(:branch, name: 'Sucursal Centro')

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
      branch = create(:branch)
      branch_user = create(:user)
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
      branch = create(:branch)

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
      branch = create(:branch, name: 'Sucursal Centro')

      delete admin_branch_path(branch), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('branches_list')
      expect(response.body).not_to include('Sucursal Centro')
      expect(response.body).to include(I18n.t('admin.branches.destroyed'))
      expect(branch.reload.deleted_at).to be_present
    end

    it 'forbids branch-only users from deleting branches' do
      branch = create(:branch)
      branch_user = create(:user)
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
      branch = create(:branch, name: 'Unchanged Branch')

      patch admin_branch_path(branch), params: { branch: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
      expect(branch.reload.name).to eq('Unchanged Branch')
    end

    it 'builds an address when an invalid update targets a branch without one' do
      branch = create(:branch, :without_address)

      patch admin_branch_path(branch), params: { branch: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include('address_attributes')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
    end
  end
end

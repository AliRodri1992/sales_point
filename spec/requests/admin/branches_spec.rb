require 'rails_helper'

RSpec.describe 'Admin::Branches', type: :request do
  let(:user) { create(:user) }
  let(:branch_role) { create(:system_role, :branch) }

  before { sign_in user }

  describe 'GET /admin/branches' do
    before { allow(user).to receive(:admin?).and_return(true) }

    it 'renders the branches page' do
      create(:branch, name: 'Sucursal Centro')

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Centro')
    end

    it 'paginates branches with 10 records by default' do
      Array.new(11) { |index| create(:branch, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('branches-per-page')
      expect(response.body).to include('Sucursal 1')
      expect(response.body).to include('Sucursal 10')
      expect(response.body).not_to include('Sucursal 11')
      expect(response.body).to include('aria-current="page">1</span>')
    end

    it 'allows selecting 5 records per page' do
      Array.new(11) { |index| create(:branch, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 5 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal 1')
      expect(response.body).to include('Sucursal 5')
      expect(response.body).not_to include('Sucursal 6')
      expect(response.body).to include('value="5" selected="selected"')
    end

    it 'does not expose branches outside the current user access' do
      allow(user).to receive(:admin?).and_return(false)
      assigned_branch = create(:branch, name: 'Sucursal Asignada')
      create(:branch, name: 'Sucursal Restringida')
      create(:user_role, user:, system_role: branch_role, branch: assigned_branch)

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Asignada')
      expect(response.body).not_to include('Sucursal Restringida')
    end
  end

  describe 'GET /admin/branches/new' do
    it 'renders the new branch screen without a modal for system administrators' do
      allow(user).to receive(:admin?).and_return(true)

      get new_admin_branch_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Nueva sucursal')
      expect(response.body).to include('action="/admin/branches"')
      expect(response.body).not_to include('data-branches-target="modal"')
    end

    it 'forbids branch-only users from creating branches' do
      create(:user_role, user:, system_role: branch_role, branch: create(:branch))

      get new_admin_branch_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /admin/branches/:id' do
    it 'shows an assigned branch to a branch user' do
      branch = create(:branch, name: 'Sucursal Centro')
      create(:user_role, user:, system_role: branch_role, branch:)

      get admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Centro')
      expect(response.body).to include('Av. Reforma')
    end

    it 'does not expose another branch to a branch user' do
      branch = create(:branch)
      create(:user_role, user:, system_role: branch_role, branch: create(:branch))

      get admin_branch_path(branch)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /admin/branches' do
    before { allow(user).to receive(:admin?).and_return(true) }

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
      expect(response.body).to include('Nombre no puede estar vacío.')
      expect(response.body).to include('Código postal no puede estar vacío.')
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
      notification = user.notifications.last
      expect(notification.event.params['action']).to eq('created')
      expect(notification.event.params['user_name']).to eq(user.display_name)
    end

    it 'forbids branch-only users from creating branches' do
      allow(user).to receive(:admin?).and_return(false)
      create(:user_role, user:, system_role: branch_role, branch: create(:branch))

      post admin_branches_path, params: { branch: { name: 'No autorizada', status: true } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /admin/branches/:id/edit' do
    it 'renders the edit branch screen for a system administrator' do
      allow(user).to receive(:admin?).and_return(true)
      branch = create(:branch, name: 'Sucursal Centro')

      get edit_admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
      expect(response.body).not_to include('data-branches-target="modal"')
    end

    it 'forbids branch-only users from editing branches' do
      branch = create(:branch)
      create(:user_role, user:, system_role: branch_role, branch:)

      get edit_admin_branch_path(branch)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /admin/branches/:id' do
    it 'updates a branch and creates a notification' do
      allow(user).to receive(:admin?).and_return(true)
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
      expect(branch.reload.name).to eq('Sucursal Norte')
      expect(branch.address.reload.city).to eq('Tlalnepantla')

      notification = user.notifications.last
      expect(notification.event.params['action']).to eq('updated')
      expect(notification.event.params['user_name']).to eq(user.display_name)
    end

    it 'forbids branch-only users from updating branches' do
      branch = create(:branch)
      create(:user_role, user:, system_role: branch_role, branch:)

      patch admin_branch_path(branch), params: { branch: { name: 'No autorizada' } }

      expect(response).to have_http_status(:forbidden)
      expect(branch.reload.name).not_to eq('No autorizada')
    end
  end

  describe 'DELETE /admin/branches/:id' do
    it 'soft deletes a branch and creates a notification with the actor' do
      allow(user).to receive(:admin?).and_return(true)
      branch = create(:branch)

      expect do
        delete admin_branch_path(branch)
      end.to change(Noticed::Notification, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
      expect(branch.reload.deleted_at).to be_present

      notification = user.notifications.last
      expect(notification.event.record).to eq(branch)
      expect(notification.event.params['action']).to eq('destroyed')
      expect(notification.event.params['user_name']).to eq(user.display_name)
    end

    it 'updates the list and shows a success toast for Turbo requests' do
      allow(user).to receive(:admin?).and_return(true)
      branch = create(:branch, name: 'Sucursal Centro')

      delete admin_branch_path(branch), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('branches_list')
      expect(response.body).not_to include('Sucursal Centro')
      expect(response.body).to include(t('admin.branches.destroyed'))
      expect(branch.reload.deleted_at).to be_present
    end

    it 'forbids branch-only users from deleting branches' do
      branch = create(:branch)
      create(:user_role, user:, system_role: branch_role, branch:)

      delete admin_branch_path(branch)

      expect(response).to have_http_status(:forbidden)
      expect(branch.reload.deleted_at).to be_nil
    end
  end
end

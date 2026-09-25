require 'rails_helper'

RSpec.describe 'Admin::Branches', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /admin/branches' do
    it 'renders the branches page' do
      create(:branch, name: 'Sucursal Centro')
      get admin_branches_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Centro')
    end

    it 'paginates branches with 10 records by default' do
      create_list(:branch, 11)
      get admin_branches_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('branches-per-page')
      expect(response.body.scan('<tr class="transition hover:bg-slate-50">').size).to eq(10)
      expect(response.body).to include('aria-current="page">1</span>')
      expect(response.body).to include('>2<')
    end

    it 'allows selecting 5 records per page' do
      create_list(:branch, 11)
      get admin_branches_path, params: { per_page: 5 }
      expect(response).to have_http_status(:ok)
      expect(response.body.scan('<tr class="transition hover:bg-slate-50">').size).to eq(5)
      expect(response.body).to include('value="5" selected="selected"')
    end
  end

  describe 'GET /admin/branches/new' do
    it 'renders the new branch screen without a modal' do
      get new_admin_branch_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Nueva sucursal')
      expect(response.body).not_to include('data-branches-target="modal"')
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
  end

  describe 'GET /admin/branches/:id/edit' do
    it 'renders the edit branch screen without a modal' do
      branch = create(:branch, name: 'Sucursal Centro')
      get edit_admin_branch_path(branch)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).not_to include('data-branches-target="modal"')
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
      expect(branch.reload.name).to eq('Sucursal Norte')
      expect(branch.address.reload.city).to eq('Tlalnepantla')
      notification = user.notifications.last
      expect(notification.event.params['action']).to eq('updated')
      expect(notification.event.params['user_name']).to eq(user.display_name)
    end
  end

  describe 'DELETE /admin/branches/:id' do
    it 'soft deletes a branch and creates a notification with the actor' do
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
  end
end

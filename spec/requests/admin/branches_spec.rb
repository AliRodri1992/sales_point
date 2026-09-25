require 'rails_helper'

RSpec.describe 'Admin::Branches', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /admin/branches' do
    it 'renders the branches page' do
      create(:branch, name: 'Sucursal Centro')

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Centro')
    end
  end

  describe 'POST /admin/branches' do
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
      expect(response.request.flash[:swal_message]).to eq('Sucursal creada correctamente.')
    end
  end

  describe 'PATCH /admin/branches/:id' do
    it 'updates a branch and creates a notification' do
      branch = create(:branch, name: 'Sucursal Centro')

      expect do
        patch admin_branch_path(branch), params: {
          branch: {
            name: 'Sucursal Norte',
            address_attributes: {
              id: branch.address.id,
              city: 'Tlalnepantla'
            }
          }
        }
      end.to change(Noticed::Notification, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
      expect(branch.reload.name).to eq('Sucursal Norte')
      expect(branch.address.reload.city).to eq('Tlalnepantla')
      expect(response.request.flash[:swal_message]).to eq('Sucursal actualizada correctamente.')
    end
  end

  describe 'DELETE /admin/branches/:id' do
    it 'soft deletes a branch and creates a notification' do
      branch = create(:branch)

      expect do
        delete admin_branch_path(branch)
      end.to change(Noticed::Notification, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
      expect(branch.reload.deleted_at).to be_present
      expect(response.request.flash[:swal_message]).to eq('Sucursal eliminada correctamente.')
    end
  end
end

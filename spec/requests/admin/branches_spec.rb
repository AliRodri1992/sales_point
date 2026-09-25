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
    it 'creates a branch' do
      expect do
        post admin_branches_path, params: {
          branch: {
            name: 'Sucursal Centro',
            phone: '5551234567',
            address: 'Centro',
            status: true
          }
        }
      end.to change(Branch, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
    end
  end

  describe 'PATCH /admin/branches/:id' do
    it 'updates a branch' do
      branch = create(:branch, name: 'Sucursal Centro')

      patch admin_branch_path(branch), params: {
        branch: { name: 'Sucursal Norte' }
      }

      expect(response).to redirect_to(admin_branches_path)
      expect(branch.reload.name).to eq('Sucursal Norte')
    end
  end

  describe 'DELETE /admin/branches/:id' do
    it 'soft deletes a branch' do
      branch = create(:branch)

      expect do
        delete admin_branch_path(branch)
      end.not_to change(Branch, :count)

      expect(response).to redirect_to(admin_branches_path)
      expect(branch.reload.deleted_at).to be_present
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SystemRoles', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:admin_role) { create(:system_role, name: 'Administrator', code: 'administrator', role_type: :system) }
  let!(:admin) { create(:user, :english) }
  let!(:membership) { create(:user_role, user: admin, system_role: admin_role) }

  before { sign_in admin }

  after { sign_out admin }

  describe 'POST /system_roles' do
    it 'delivers the create confirmation as a SweetAlert2 flash' do
      post system_roles_path,
           params: { system_role: { name: 'Sales Supervisor', role_type: 'branch', status: 'active' } }

      expect(response).to redirect_to(system_role_path(SystemRole.find_by!(name: 'Sales Supervisor')))
      expect(flash[:swal_message]).to eq(I18n.t('system_roles.create.success'))
      expect(flash[:notice]).to be_nil
    end
  end
end

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

    it 'delivers a notification to the admin notifications panel' do
      expect do
        post system_roles_path,
             params: { system_role: { name: 'Auditor', role_type: 'branch', status: 'active' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = admin.notifications.last
      expect(notification.type).to eq('SystemRoleNotification::Notification')
      expect(notification.event.record.name).to eq('Auditor')
      expect(notification.event.params[:action]).to eq('created')
    end
  end

  describe 'breadcrumb' do
    def breadcrumb_trail
      Nokogiri::HTML4(response.body).at_css('nav ol').css('a').map { |node| node.text.strip }
    end

    it 'renders the roles trail in English' do
      get system_roles_path

      expect(breadcrumb_trail).to eq(%w[Home Roles])
      expect(response.body).not_to include('translation missing')
    end

    it 'renders the roles trail in Spanish' do
      spanish_user = create(:user, :spanish)
      create(:user_role, user: spanish_user, system_role: admin_role)
      sign_in spanish_user

      get system_roles_path

      expect(breadcrumb_trail).to eq(%w[Inicio Roles])
      expect(response.body).not_to include('translation missing')
    end
  end

  describe 'PATCH /system_roles/:id/permissions' do
    let!(:role) { create(:system_role, name: 'Cajero', code: 'cashier', role_type: :branch) }
    let!(:permission) { create(:permission) }

    it 'delivers a notification to the admin notifications panel' do
      expect do
        patch permissions_system_role_path(role), params: { permission_ids: [permission.id] }
      end.to change(Noticed::Notification, :count).by(1)

      notification = admin.notifications.last
      expect(notification.type).to eq('SystemRoleNotification::Notification')
      expect(notification.event.record).to eq(role)
      expect(notification.event.params[:action]).to eq('updated')
    end

    it 'shows the notification in the panel' do
      patch permissions_system_role_path(role), params: { permission_ids: [permission.id] }

      get system_role_path(role)

      panel = Nokogiri::HTML4(response.body).at_css('#notifications_list').text
      expect(panel).to include(I18n.t('admin.shared.notifications.system_role.updated', name: role.name))
      expect(panel).to include(I18n.t('admin.shared.notifications.types.system_role'))
    end
  end
end

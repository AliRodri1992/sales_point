# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin user statuses', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator_role) { create(:system_role, :system, code: 'administrator') }
  let(:admin) { create(:user, system_roles: [administrator_role]) }
  let(:target) { create(:user, status: :active) }

  before do
    create(:organization_membership, user: admin, organization:)
    create(:organization_membership, user: target, organization:)
    sign_in admin
  end

  it 'requires a reason and records an authorized suspension' do
    patch admin_user_status_path(target), params: { transition: 'suspended', reason: '' }
    expect(target.reload).to be_active

    expect do
      patch admin_user_status_path(target), params: { transition: 'suspended', reason: 'Ausencia temporal' }
    end.to change(UserStatusEvent, :count).by(1)

    expect(target.reload).to be_suspended
    expect(UserStatusEvent.last.reason).to eq('Ausencia temporal')
  end

  it 'prevents an administrator from changing their own status' do
    patch admin_user_status_path(admin), params: { transition: 'suspended', reason: 'Self change' }
    expect(admin.reload).to be_active
  end

  it 'does not allow forged direct transitions' do
    patch admin_user_status_path(target), params: { transition: 'pending', reason: 'Forged' }
    expect(target.reload).to be_active
  end
end

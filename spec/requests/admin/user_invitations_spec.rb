# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin user invitation delivery', type: :request do
  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:administrator) { create(:user, system_roles: [role]) }
  let(:user) { create(:user, status: :pending, user_type: :customer) }

  before do
    permission = Permission.find_or_create_by!(code: 'users.resend_invitation') do |record|
      record.name = 'Resend invitations'
      record.module_name = 'Usuarios'
      record.status = :active
    end
    SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    create(:organization_membership, user: administrator, organization:)
    create(:organization_membership, user:, organization:, account_status: :pending)
    sign_in administrator
  end

  def resend
    post admin_user_invitation_path(user)
  end

  it 'queues a new invitation with an encrypted token' do
    expect { resend }.to have_enqueued_job(Users::InvitationDeliveryJob)
    expect(response).to redirect_to(admin_user_path(user))
    expect(user.user_invitations.last.delivery_status).to eq('queued')
  end

  it 'enforces a cooldown without replacing a recent invitation' do
    invitation = UserInvitation.issue!(user:, organization:)
    expect { resend }.not_to change(UserInvitation, :count)
    expect(response).to redirect_to(admin_user_path(user))
    expect(flash[:alert]).to eq(I18n.t('admin.users.status_management.resend_cooldown'))
    expect(invitation.reload.revoked_at).to be_nil
  end

  it 'allows immediate retry after failed delivery' do
    invitation = UserInvitation.issue!(user:, organization:)
    invitation.update!(delivery_status: 'failed')
    expect { resend }.to have_enqueued_job(Users::InvitationDeliveryJob)
    expect(invitation.reload.revoked_at).to be_present
  end

  it 'reports queue failures and keeps the invitation available for retry' do
    allow(Users::InvitationDeliveryJob).to receive(:perform_later).and_raise(IOError, 'Queue unavailable')
    resend
    expect(response).to redirect_to(admin_user_path(user))
    expect(flash[:alert]).to eq(I18n.t('admin.users.status_management.invitation_delivery_failed'))
    expect(user.user_invitations.last.delivery_status).to eq('failed')
  end

  it 'rejects accounts outside the selected organization' do
    user.organization_memberships.find_by!(organization:).update!(organization: create(:organization))
    resend
    expect(response).to have_http_status(:not_found)
  end

  it 'allows a pending invitation to a second organization without resetting credentials' do
    create(:organization_membership, user:)
    expect { resend }.to change(UserInvitation, :count).by(1)
    expect(response).to redirect_to(admin_user_path(user))
  end

  it 'does not expose resend for a pending employee without any active roles' do
    user.update!(user_type: :employee)
    get admin_user_path(user)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('admin.users.ui.invitation_not_ready'))
    expect(Nokogiri::HTML(response.body).css("form[action='#{admin_user_invitation_path(user)}']")).to be_empty
    expect { resend }.not_to change(UserInvitation, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it 'requires the account to be pending locally' do
    user.organization_memberships.find_by!(organization:).update!(account_status: :active)
    expect { resend }.not_to change(UserInvitation, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it 'hides the resend action when its explicit permission is revoked' do
    role.system_role_permissions.destroy_all
    get admin_user_path(user)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css("form[action='#{admin_user_invitation_path(user)}']")).to be_empty
  end

  it 'requires explicit permission to resend' do
    role.system_role_permissions.destroy_all
    expect { resend }.not_to change(UserInvitation, :count)
    expect(response).to have_http_status(:forbidden)
  end
end

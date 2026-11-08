# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin user statuses', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator_role) { create(:system_role, :system, code: 'administrator') }
  let(:admin) { create(:user, system_roles: [administrator_role]) }
  let(:target) { create(:user, status: :active) }

  before do
    %w[suspend reactivate block unblock destroy].each do |action|
      permission = Permission.find_or_create_by!(code: "users.#{action}") do |item|
        item.name = "Manage user #{action}"
        item.module_name = 'Usuarios'
        item.status = :active
      end
      SystemRolePermission.find_or_create_by!(system_role: administrator_role, permission:)
    end
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

  it 'renders inline model errors without HTML required when the reason is blank' do
    get edit_admin_user_status_path(target), params: { transition: 'suspended' }
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css('textarea#reason[required]')).to be_empty

    patch admin_user_status_path(target), params: { transition: 'suspended', reason: '' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css('#users_status_transition_reason_error')).to be_present
    expect(target.reload).to be_active
  end

  it 'validates a future suspension review date in the model' do
    patch admin_user_status_path(target), params: {
      transition: 'suspended', reason: 'Future check', review_at: 1.day.ago.iso8601
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css('#users_status_transition_review_at_error')).to be_present
  end

  it 'renders a field error when an incident resolution is missing' do
    patch admin_user_status_path(target), params: { transition: 'blocked', reason: 'Incident review' }
    patch admin_user_status_path(target), params: { transition: 'active', reason: 'Reviewed' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css('#users_status_transition_resolution_error')).to be_present
  end

  it 'shows a translated status-transition error instead of the internal exception' do
    form = Users::StatusTransition.new(
      user: target, actor: admin, organization:, target: 'suspended', reason: 'Review'
    )
    allow(Users::StatusTransition).to receive(:new).and_return(form)
    allow(form).to receive(:call).and_raise(ArgumentError, 'Transition not permitted')

    patch admin_user_status_path(target), params: { transition: 'suspended', reason: 'Review' }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t('admin.users.status_management.errors.transition_not_permitted'))
    expect(response.body).not_to include('Transition not permitted')
  end

  it 'prevents an administrator from changing their own status' do
    patch admin_user_status_path(admin), params: { transition: 'suspended', reason: 'Self change' }
    expect(admin.reload).to be_active
  end

  it 'suspends only the selected organization for shared accounts' do
    second_organization = create(:organization)
    second_membership = create(:organization_membership, user: target, organization: second_organization)
    patch admin_user_status_path(target), params: { transition: 'suspended', reason: 'Tenant review' }

    expect(response).to redirect_to(admin_user_path(target))
    expect(target.reload).to be_active
    expect(target.session_revoked_at).to be_present
    expect(target.organization_memberships.find_by!(organization:).account_status).to eq('suspended')
    expect(second_membership.reload.account_status).to eq('active')
  end

  it 'requires incident resolution for unlocking a blocked account' do
    patch admin_user_status_path(target), params: { transition: 'blocked', reason: 'Security incident' }
    expect(UserSecurityIncident.where(user: target, organization:).count).to eq(1)

    patch admin_user_status_path(target), params: { transition: 'active', reason: 'Reviewed' }
    expect(target.organization_memberships.find_by!(organization:).account_status).to eq('blocked')

    patch admin_user_status_path(target), params: {
      transition: 'active', reason: 'Reviewed', resolution: 'Identity verified by administrator'
    }
    expect(target.organization_memberships.find_by!(organization:).account_status).to eq('active')
    expect(UserSecurityIncident.find_by!(user: target, organization:).resolved_at).to be_present
  end

  it 'issues a new invitation when a pending account is unblocked' do
    target.update!(status: :pending)
    target.organization_memberships.find_by!(organization:).update!(account_status: :pending)

    patch admin_user_status_path(target), params: {
      transition: 'blocked', reason: 'Seguridad de la cuenta'
    }
    expect(target.reload).to be_blocked

    expect do
      patch admin_user_status_path(target), params: {
        transition: 'pending', reason: 'Verificación completada', resolution: 'Identidad confirmada'
      }
    end.to change(UserInvitation, :count).by(1)

    expect(response).to redirect_to(admin_user_path(target))
    expect(target.reload).to be_pending
    expect(target.user_invitations.last).to be_usable
  end

  it 'revokes the account session on an authorized block' do
    patch admin_user_status_path(target), params: { transition: 'blocked', reason: 'Security incident' }
    expect(target.reload).to be_blocked
    expect(target.session_revoked_at).to be_present
  end

  it 'does not allow forged direct transitions' do
    patch admin_user_status_path(target), params: { transition: 'pending', reason: 'Forged' }
    expect(target.reload).to be_active
  end

  it 'does not render a confirmation form for a transition that is not allowed' do
    get edit_admin_user_status_path(target), params: { transition: 'pending' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(target.reload).to be_active
  end
end

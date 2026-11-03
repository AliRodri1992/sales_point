# frozen_string_literal: true

module Admin
  class UserInvitationsController < ApplicationController
    before_action :authenticate_user!

    def create
      members = current_organization.organization_memberships.active.where(deleted_at: nil).select(:user_id)
      user = policy_scope(User).where(id: members).find(params[:user_id])
      authorize user, :update?
      raise Pundit::NotAuthorizedError unless user.pending? && current_user.permission?('users.resend_invitation')
      raise Pundit::NotAuthorizedError if user.organization_memberships.active.where.not(organization: current_organization).exists?

      if user.user_invitations.order(created_at: :desc).where('created_at > ?', 60.seconds.ago).exists?
        return redirect_to admin_user_path(user), alert: t('admin.users.status_management.resend_cooldown')
      end

      Users::InvitationDispatcher.call(user:, organization: current_organization)
      redirect_to admin_user_path(user), notice: t('admin.users.status_management.resent')
    end
  end
end

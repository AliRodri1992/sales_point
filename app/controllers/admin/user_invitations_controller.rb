# frozen_string_literal: true

module Admin
  class UserInvitationsController < ApplicationController
    before_action :authenticate_user!

    def create
      user = invitation_user
      validate_access!(user)
      return resend_limited(user) if resend_limited?(user)

      Users::InvitationDispatcher.call(user:, organization: current_organization)
      redirect_to admin_user_path(user), notice: t('admin.users.status_management.resent')
    end

    private

    def invitation_user
      member_ids = current_organization.organization_memberships.active.select(:user_id)
      policy_scope(User).where(id: member_ids).find(params[:user_id])
    end

    def validate_access!(user)
      authorize user, :update?
      raise Pundit::NotAuthorizedError unless user.pending? && current_user.permission?('users.resend_invitation')

      other_memberships = user.organization_memberships.active.where.not(organization: current_organization)
      raise Pundit::NotAuthorizedError if other_memberships.exists?
    end

    def resend_limited?(user)
      user.user_invitations.order(created_at: :desc).exists?(['created_at > ?', 60.seconds.ago])
    end

    def resend_limited(user)
      redirect_to admin_user_path(user), alert: t('admin.users.status_management.resend_cooldown')
    end
  end
end

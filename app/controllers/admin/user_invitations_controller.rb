# frozen_string_literal: true

module Admin
  class UserInvitationsController < ApplicationController
    before_action :authenticate_user!
    before_action { head :forbidden unless current_organization }

    def create
      user = invitation_user
      validate_access!(user)
      return resend_limited(user) if resend_limited?(user)

      Users::InvitationDispatcher.call(user:, organization: current_organization)
      redirect_to admin_user_path(user), notice: t('admin.users.status_management.resent')
    end

    rescue_from Users::InvitationDispatcher::DeliveryError, with: :delivery_failed
    rescue_from ArgumentError, with: :invitation_unavailable

    private

    def invitation_unavailable
      redirect_to admin_user_path(params[:user_id]), alert: t('admin.users.ui.invitation_not_ready')
    end

    def delivery_failed
      message = t('admin.users.status_management.invitation_delivery_failed')
      redirect_to admin_user_path(params[:user_id]), alert: message
    end

    def invitation_user
      member_ids = current_organization.organization_memberships.active.select(:user_id)
      policy_scope(User).where(id: member_ids).find(params[:user_id])
    end

    def validate_access!(user)
      authorize user, :resend_invitation?
      membership = user.organization_memberships.active.find_by(organization: current_organization)
      permitted = current_user.permission?('users.resend_invitation', organization: current_organization)
      allowed = membership&.account_pending? && permitted
      raise Pundit::NotAuthorizedError unless allowed
      raise Pundit::NotAuthorizedError unless Users::InvitationEligibility.ready?(
        user:, organization: current_organization
      )
    end

    def resend_limited?(user)
      user.user_invitations.where(organization: current_organization).where.not(delivery_status: 'failed')
          .exists?(['created_at > ?', 60.seconds.ago])
    end

    def resend_limited(user)
      redirect_to admin_user_path(user), alert: t('admin.users.status_management.resend_cooldown')
    end
  end
end

# frozen_string_literal: true

module Admin
  class UserInvitationsController < ApplicationController
    before_action :authenticate_user!

    def create
      members = current_organization.organization_memberships.active.where(deleted_at: nil).select(:user_id)
      user = policy_scope(User).where(id: members).find(params[:user_id])
      authorize user, :update?
      raise Pundit::NotAuthorizedError unless user.pending?

      Users::InvitationDispatcher.call(user:, organization: current_organization)
      redirect_to admin_user_path(user), notice: t('admin.users.status_management.resent')
    end
  end
end

# frozen_string_literal: true

module Users
  class AccountRestoration
    def initialize(user:, actor:, organization:, reason:)
      @user = user
      @actor = actor
      @organization = organization
      @reason = reason.to_s.strip
    end

    def call!
      raise ArgumentError, 'Reason required' if @reason.blank? || @reason.length > 1000

      @organization.with_lock do
        User.transaction do
          @user.lock!
          @membership = @user.organization_memberships.active.lock.find_by!(organization: @organization)
          verify_access!
          Users::OrganizationCapacity.new(organization: @organization).ensure_available!
          restore_account!
        end
      end
    end

    private

    def verify_access!
      verify_actor!
      verify_target!
    end

    def verify_actor!
      raise Pundit::NotAuthorizedError unless @actor.active? && @actor.role?('super_admin')
      raise Pundit::NotAuthorizedError unless @actor.permission?('users.restore')
      raise Pundit::NotAuthorizedError unless @organization&.active?

      allowed = @actor.organization_memberships.accessible.exists?(organization: @organization)
      raise Pundit::NotAuthorizedError unless allowed
    end

    def verify_target!
      raise Pundit::NotAuthorizedError if @user == @actor || !@membership.account_deleted?
    end

    def restore_account!
      shared = @user.organization_memberships.active.where.not(organization: @organization).exists?
      next_status = shared && @user.active? ? 'active' : 'pending'
      @membership.update!(account_status: next_status, status_review_at: nil)
      reset_local_access! if shared
      reset_global_account! unless shared

      UserStatusEvent.create!(
        user: @user, actor: @actor, organization: @organization,
        from_status: 'deleted', to_status: next_status, reason: @reason
      )
    end

    def reset_local_access!
      branch_ids = @organization.branches.select(:id)
      @user.user_roles.active.where(branch_id: branch_ids).find_each do |role|
        role.update!(deleted_at: Time.current)
      end
    end

    def reset_global_account!
      @user.user_roles.active.find_each { |role| role.update!(deleted_at: Time.current) }
      @user.update!(
        status: :pending, deleted_at: nil, session_revoked_at: Time.current,
        password: SecureRandom.urlsafe_base64(48)
      )
    end
  end
end

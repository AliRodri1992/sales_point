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

      User.transaction do
        @user.lock!
        verify_access!
        @user.user_roles.active.find_each { |role| role.update!(deleted_at: Time.current) }
        @user.update!(
          status: :pending, deleted_at: nil, session_revoked_at: Time.current,
          password: SecureRandom.urlsafe_base64(48)
        )
        UserStatusEvent.create!(
          user: @user, actor: @actor, organization: @organization,
          from_status: 'deleted', to_status: 'pending', reason: @reason
        )
      end
    end

    private

    def verify_access!
      raise Pundit::NotAuthorizedError unless @actor.active? && @actor.role?('super_admin')
      raise Pundit::NotAuthorizedError unless @actor.permission?('users.restore')
      raise Pundit::NotAuthorizedError if @user == @actor || !@user.deleted?
      raise Pundit::NotAuthorizedError unless @organization&.active?

      memberships = @user.organization_memberships.active
      raise Pundit::NotAuthorizedError unless memberships.exists?(organization: @organization)
      raise Pundit::NotAuthorizedError if memberships.where.not(organization: @organization).exists?
      raise Pundit::NotAuthorizedError unless @actor.organization_memberships.active.exists?(organization: @organization)
    end
  end
end

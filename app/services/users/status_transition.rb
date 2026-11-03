# frozen_string_literal: true

module Users
  class StatusTransition
    ALLOWED = {
      'active' => %w[suspended blocked deleted],
      'pending' => %w[blocked deleted],
      'suspended' => %w[active blocked deleted],
      'blocked' => %w[active suspended pending deleted]
    }.freeze

    def self.allowed_targets(user)
      targets = ALLOWED.fetch(user.status, [])
      return targets unless user.blocked?

      previous = UserStatusEvent.where(user:).where(to_status: 'blocked').order(id: :desc).pick(:from_status)
      targets & [previous, 'deleted']
    end

    def initialize(user:, actor:, organization:, target:, reason:)
      @user = user
      @actor = actor
      @organization = organization
      @target = target.to_s
      @reason = reason.to_s.strip
    end

    def call!
      validate_request!
      User.transaction do
        @user.lock!
        raise ArgumentError, 'Transition not permitted' unless self.class.allowed_targets(@user).include?(@target)

        prevent_last_admin!
        persist_transition!
      end
    end

    private

    def validate_request!
      validate_reason!
      validate_actor!
      validate_membership!
    end

    def validate_reason!
      raise ArgumentError, 'Reason required' if @reason.blank? || @reason.length > 1000
    end

    def validate_actor!
      raise Pundit::NotAuthorizedError unless @actor.admin?
      raise Pundit::NotAuthorizedError if @user == @actor
      raise Pundit::NotAuthorizedError if @user.admin? && !@actor.role?('super_admin')
    end

    def validate_membership!
      memberships = @user.organization_memberships.active
      raise Pundit::NotAuthorizedError unless memberships.exists?(organization: @organization)

      return unless @target == 'deleted' && memberships.where.not(organization: @organization).exists?

      raise Pundit::NotAuthorizedError
    end

    def persist_transition!
      previous = @user.status
      attributes = { status: @target }
      attributes[:session_revoked_at] = Time.current unless @target == 'active'
      attributes[:deleted_at] = Time.current if @target == 'deleted'
      @user.update!(attributes)
      UserInvitation.revoke_for!(@user) if %w[blocked deleted].include?(@target)
      UserStatusEvent.create!(user: @user, organization: @organization, actor: @actor,
                              from_status: previous, to_status: @target, reason: @reason)
    end

    def prevent_last_admin!
      return unless @user.admin? && @target != 'active'

      members = @organization.organization_memberships.active.where(deleted_at: nil).select(:user_id)
      count = User.where(id: members, status: 'active', deleted_at: nil)
                  .joins(user_roles: :system_role)
                  .where(system_roles: { code: %w[super_admin administrator] }).distinct.count
      raise ArgumentError, 'Cannot disable the last administrator' if count <= 1
    end
  end
end

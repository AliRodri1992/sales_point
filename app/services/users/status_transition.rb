# frozen_string_literal: true

module Users
  class StatusTransition
    ALLOWED = {
      'active' => %w[suspended blocked],
      'pending' => %w[blocked],
      'suspended' => %w[active blocked],
      'blocked' => %w[active suspended pending]
    }.freeze

    def self.allowed_targets(user)
      targets = ALLOWED.fetch(user.status, [])
      return targets unless user.blocked?

      previous = UserStatusEvent.where(user:).where(to_status: 'blocked').order(id: :desc).pick(:from_status)
      targets & [previous]
    end

    def initialize(user:, actor:, organization:, target:, reason:)
      @user = user
      @actor = actor
      @organization = organization
      @target = target.to_s
      @reason = reason.to_s.strip
    end

    def call!
      raise ArgumentError, 'Reason required' if @reason.blank? || @reason.length > 1000
      raise Pundit::NotAuthorizedError unless @actor.admin?
      raise Pundit::NotAuthorizedError if @user == @actor
      raise Pundit::NotAuthorizedError unless @user.organization_memberships.active.exists?(organization: @organization)
      raise Pundit::NotAuthorizedError if @user.admin? && !@actor.role?('super_admin')

      User.transaction do
        @user.lock!
        raise ArgumentError, 'Transition not permitted' unless self.class.allowed_targets(@user).include?(@target)
        prevent_last_admin!
        before = @user.status
        @user.update!(status: @target)
        @user.update_columns(session_revoked_at: Time.current) if @target != 'active'
        UserStatusEvent.create!(user: @user, organization: @organization, actor: @actor,
                                from_status: before, to_status: @target, reason: @reason)
      end
    end

    private

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

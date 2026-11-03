# frozen_string_literal: true

module Users
  class StatusTransition
    ALLOWED = {
      'active' => %w[suspended blocked deleted],
      'pending' => %w[blocked deleted],
      'suspended' => %w[active blocked deleted],
      'blocked' => %w[active suspended pending deleted]
    }.freeze

    PERMISSIONS = {
      'active' => 'users.reactivate',
      'suspended' => 'users.suspend',
      'blocked' => 'users.block',
      'deleted' => 'users.destroy',
      'pending' => 'users.unblock'
    }.freeze

    def self.allowed_targets(user, organization: nil)
      targets = ALLOWED.fetch(user.status, [])
      return targets unless user.blocked?

      events = UserStatusEvent.where(user:, to_status: 'blocked')
      events = events.where(organization:) if organization
      previous = events.order(id: :desc).pick(:from_status)
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
      raise ArgumentError, 'Reason required' if @reason.blank? || @reason.length > 1000

      User.transaction do
        @user.lock!
        validate_access!
        raise ArgumentError, 'Transition not permitted' unless self.class.allowed_targets(
          @user, organization: @organization
        ).include?(@target)

        prevent_last_admin!
        persist_transition!
      end
      notify_account_holder
    end

    private

    def validate_access!
      raise Pundit::NotAuthorizedError if @user == @actor
      raise Pundit::NotAuthorizedError unless @organization&.active?
      raise Pundit::NotAuthorizedError unless member?(@user) && member?(@actor)
      raise Pundit::NotAuthorizedError if shared_account?
      raise Pundit::NotAuthorizedError unless actor_authorized?
    end

    def member?(user)
      user.organization_memberships.active.exists?(organization: @organization)
    end

    def shared_account?
      @user.organization_memberships.active.where.not(organization: @organization).exists?
    end

    def actor_authorized?
      return false unless @actor.active? && @actor.admin?
      return false unless @actor.permission?(transition_permission)
      return true unless @user.admin?

      @actor.role?('super_admin') && !@user.role?('super_admin')
    end

    def transition_permission
      return 'users.unblock' if @user.blocked? && @target != 'deleted'

      PERMISSIONS.fetch(@target)
    end

    def prevent_last_admin!
      return unless @user.admin? && @target != 'active'

      members = @organization.organization_memberships.active.select(:user_id)
      remaining = User.where(id: members, status: 'active', deleted_at: nil)
                      .where.not(id: @user.id)
                      .joins(user_roles: :system_role)
                      .where(system_roles: { code: SystemRole::ADMINISTRATIVE_CODES })
                      .distinct
      raise ArgumentError, 'Cannot disable the last administrator' unless remaining.exists?
    end

    def notify_account_holder
      EmailTemplate.ensure_status_template!
      UserStatusMailer.changed(@status_event.id).deliver_later
      return if @user.deleted?

      UserStatusNotification.with(record: @user, action: @target, user: @actor)
                            .deliver(@user, enqueue_job: false)
    rescue StandardError => e
      Rails.logger.error("User status notification failed: #{e.class}")
    end

    def persist_transition!
      from = @user.status
      changes = { status: @target }
      changes[:session_revoked_at] = Time.current unless @target == 'active'
      changes[:deleted_at] = Time.current if @target == 'deleted'
      @user.update!(changes)
      UserInvitation.revoke_for!(@user) if %w[blocked deleted].include?(@target)
      @status_event = UserStatusEvent.create!(user: @user, organization: @organization, actor: @actor,
                              from_status: from, to_status: @target, reason: @reason)
    end
  end
end

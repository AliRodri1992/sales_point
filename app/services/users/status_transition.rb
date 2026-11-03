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
      status = organization ? user.organization_memberships.active.find_by(organization:)&.account_status : user.status
      targets = ALLOWED.fetch(status, [])
      return targets unless status == 'blocked'

      events = UserStatusEvent.where(user:, to_status: 'blocked')
      events = events.where(organization:) if organization
      previous = events.order(id: :desc).pick(:from_status)
      targets & [previous, 'deleted']
    end

    def initialize(user:, actor:, organization:, target:, reason:, review_at: nil, resolution: nil)
      @user = user
      @actor = actor
      @organization = organization
      @target = target.to_s
      @reason = reason.to_s.strip
      @review_at = review_at.presence
      @resolution = resolution.to_s.strip
    end

    def call!
      raise ArgumentError, 'Reason required' if @reason.blank? || @reason.length > 1000

      User.transaction do
        @user.lock!
        @membership = @user.organization_memberships.active.lock.find_by!(organization: @organization)
        validate_access!
        raise ArgumentError, 'Transition not permitted' unless self.class.allowed_targets(
          @user, organization: @organization
        ).include?(@target)

        prevent_last_admin!
        validate_incident!
        persist_transition!
      end
      notify_account_holder
    end

    private

    def validate_access!
      raise Pundit::NotAuthorizedError if @user == @actor
      raise Pundit::NotAuthorizedError unless @organization&.active?
      raise Pundit::NotAuthorizedError unless member?(@user) && member?(@actor)
      raise Pundit::NotAuthorizedError unless actor_authorized?
    end

    def member?(user)
      user.organization_memberships.active.exists?(organization: @organization)
    end

    def actor_authorized?
      return false unless @actor.active? && @actor.admin?
      return false unless @actor.permission?(transition_permission)
      return true unless @user.admin?

      @actor.role?('super_admin') && !@user.role?('super_admin')
    end

    def transition_permission
      return 'users.unblock' if @membership.account_blocked? && @target != 'deleted'

      PERMISSIONS.fetch(@target)
    end

    def prevent_last_admin!
      return unless @user.admin? && @target != 'active'

      members = @organization.organization_memberships.accessible.select(:user_id)
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

    def validate_incident!
      return unless @membership.account_blocked? && @target != 'deleted'
      raise ArgumentError, 'Incident resolution required' if @resolution.blank?

      incident = @user.user_security_incidents
                      .where(organization: @organization, resolved_at: nil)
                      .order(created_at: :desc).first
      raise ArgumentError, 'Security incident not found' unless incident

      incident.update!(resolution: @resolution, resolved_at: Time.current, resolved_by: @actor)
    end

    def persist_transition!
      from = @membership.account_status
      @membership.update!(account_status: @target, status_review_at: review_date)
      apply_global_status! unless shared_membership?
      UserInvitation.revoke_for!(@user) if %w[blocked deleted].include?(@target)
      open_incident! if @target == 'blocked'
      @status_event = UserStatusEvent.create!(
        user: @user, organization: @organization, actor: @actor,
        from_status: from, to_status: @target, reason: @reason
      )
    end

    def shared_membership?
      @user.organization_memberships.active.where.not(organization: @organization).exists?
    end

    def apply_global_status!
      changes = { status: @target }
      changes[:deleted_at] = Time.current if @target == 'deleted'
      changes[:session_revoked_at] = Time.current if %w[suspended blocked deleted].include?(@target)
      @user.update!(changes)
    end

    def review_date
      return unless @target == 'suspended' && @review_at.present?

      time = Time.zone.parse(@review_at.to_s)
      raise ArgumentError, 'Review date must be in the future' unless time&.future?

      time
    end

    def open_incident!
      UserSecurityIncident.create!(
        user: @user, organization: @organization,
        opened_by: @actor, description: @reason
      )
    end
  end
end

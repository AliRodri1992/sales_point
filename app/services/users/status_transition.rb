# frozen_string_literal: true

module Users
  class StatusTransition
    include StatusTransitionValidations
    include StatusTransitionNotifications
    include StatusAdminSafety

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
      targets & [previous || 'active', 'deleted']
    end

    def initialize(**attributes)
      @user = attributes.fetch(:user)
      @actor = attributes.fetch(:actor)
      @organization = attributes.fetch(:organization)
      @target = attributes.fetch(:target).to_s
      @reason = attributes.fetch(:reason).to_s.strip
      @review_at = attributes.fetch(:details, {})[:review_at].presence
      @resolution = attributes.fetch(:details, {})[:resolution].to_s.strip
    end

    attr_reader :reason, :resolution, :review_at, :target

    def call
      return false unless valid?

      call!
      true
    end

    def call!
      raise ArgumentError, 'Reason required' if @reason.blank? || @reason.length > 1000

      # Serialize account status and role changes against the same organization lock.
      @organization.with_lock { User.transaction { execute_transition! } }
      SessionRevoker.call(@user)
      if @target == 'pending' && @user.pending? &&
         Users::InvitationEligibility.ready?(user: @user, organization: @organization)
        Users::InvitationDispatcher.call(user: @user, organization: @organization)
      end
      notify_account_holder
    end

    private

    def execute_transition!
      @user.lock!
      @membership = @user.organization_memberships.active.lock.find_by!(organization: @organization)
      validate_access!
      validate_transition!
      prevent_last_admin!
      incident_manager.validate_resolution! if @membership.account_blocked? && @target != 'deleted'
      persist_transition!
    end

    def validate_transition!
      allowed = self.class.allowed_targets(@user, organization: @organization)
      raise ArgumentError, 'Transition not permitted' unless allowed.include?(@target)
    end

    def validate_access!
      raise Pundit::NotAuthorizedError if @user == @actor
      raise Pundit::NotAuthorizedError unless @organization&.active?
      raise Pundit::NotAuthorizedError unless @user.organization_memberships.active.exists?(organization: @organization)
      raise Pundit::NotAuthorizedError unless @actor.organization_memberships.accessible.exists?(
        organization: @organization
      )
      raise Pundit::NotAuthorizedError unless actor_authorized?
    end

    def actor_authorized?
      return false unless @actor.active?
      return false unless UserPolicy.new(@actor, @user).manage_status?
      return false unless @actor.permission?(transition_permission, organization: @organization)
      return true unless @user.admin?

      @actor.role?('super_admin') && !@user.role?('super_admin')
    end

    def transition_permission
      return 'users.unblock' if @membership.account_blocked? && @target != 'deleted'

      PERMISSIONS.fetch(@target)
    end

    def persist_transition!
      from = @membership.account_status
      @membership.update!(account_status: @target, status_review_at: incident_manager.review_date(@target, @review_at))
      if shared_membership?
        @user.update!(session_revoked_at: Time.current)
      else
        apply_global_status!
      end
      UserInvitation.revoke_for!(@user, organization: @organization) if %w[blocked deleted].include?(@target)
      incident_manager.open! if @target == 'blocked'
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

    def incident_manager
      @incident_manager ||= StatusIncidentManager.new(
        user: @user, organization: @organization, actor: @actor,
        description: @reason, resolution: @resolution
      )
    end
  end
end

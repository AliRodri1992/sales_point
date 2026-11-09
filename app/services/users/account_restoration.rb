# frozen_string_literal: true

module Users
  class AccountRestoration
    include ActiveModel::Validations

    attr_reader :reason

    validates :reason, presence: true, length: { maximum: 1000 }

    def initialize(user:, actor:, organization:, reason:)
      @user = user
      @actor = actor
      @organization = organization
      @reason = reason.to_s.strip
    end

    def call
      return false unless valid?

      call!
      true
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
      raise Pundit::NotAuthorizedError unless @actor.permission?('users.restore', organization: @organization)
      raise Pundit::NotAuthorizedError unless @organization&.active?

      allowed = @actor.organization_memberships.accessible.exists?(organization: @organization)
      raise Pundit::NotAuthorizedError unless allowed
    end

    def verify_target!
      raise Pundit::NotAuthorizedError if @user == @actor || !@membership.account_deleted?
    end

    def restore_account!
      shared = @user.organization_memberships.active.where.not(organization: @organization).exists?
      globally_active = @user.active? && @user.deleted_at.nil?
      verify_shared_global_state!(shared, globally_active)
      # An employee's local roles are revoked during restoration. Require a fresh
      # invitation and review before granting access to the restored membership.
      next_status = shared && globally_active && !@user.employee? ? 'active' : 'pending'
      @membership.update!(account_status: next_status, status_review_at: nil)
      restore_access!(shared, globally_active)

      UserStatusEvent.create!(
        user: @user, actor: @actor, organization: @organization,
        from_status: 'deleted', to_status: next_status, reason: @reason
      )
    end

    def verify_shared_global_state!(shared, globally_active)
      return unless shared && !globally_active && other_accessible_membership?

      raise ArgumentError, I18n.t('admin.users.ui.shared_deleted_restore_blocked')
    end

    def restore_access!(shared, globally_active)
      if shared && globally_active
        reset_local_access!
      else
        reset_global_account!(preserve_foreign_branch_roles: shared)
      end
    end

    def other_accessible_membership?
      @user.organization_memberships.accessible.where.not(organization: @organization).exists?
    end

    def reset_local_access!
      branch_ids = @organization.branches.with_deleted.select(:id)
      @user.user_roles.where(branch_id: branch_ids).find_each do |role|
        role.update!(deleted_at: Time.current)
        audit_revocation!(role)
      end
    end

    def audit_revocation!(assignment)
      UserRoleAuditEvent.record!(
        user: @user, organization: @organization, actor: @actor, assignment:, action: 'revoked'
      )
    end

    def reset_global_account!(preserve_foreign_branch_roles: false)
      assignments = @user.user_roles.where(deleted_at: nil)
      if preserve_foreign_branch_roles
        local_branches = @organization.branches.with_deleted.select(:id)
        assignments = assignments.where(branch_id: nil).or(assignments.where(branch_id: local_branches))
      end
      assignments.find_each do |role|
        role.update!(deleted_at: Time.current)
        audit_revocation!(role)
      end
      UserInvitation.revoke_for!(@user)
      @user.update!(
        status: :pending, deleted_at: nil, session_revoked_at: Time.current,
        password: SecureRandom.urlsafe_base64(48)
      )
    end
  end
end

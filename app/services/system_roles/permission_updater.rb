# frozen_string_literal: true

module SystemRoles
  # Called inside the role's transaction/lock so the permission diff and audit event are atomic.
  class PermissionUpdater
    def initialize(role:, permission_ids:, actor:)
      @role = role
      @permission_ids = permission_ids
      @actor = actor
    end

    def call!
      before = @role.permissions.pluck(:code)
      after = Permission.where(id: @permission_ids).pluck(:code)
      persist_assignments!
      record_changes!(before:, after:)
    end

    private

    def persist_assignments!
      @role.system_role_permissions.where.not(permission_id: @permission_ids).delete_all
      @permission_ids.each do |permission_id|
        @role.system_role_permissions.find_or_create_by!(permission_id:)
      end
    end

    def record_changes!(before:, after:)
      added = after - before
      removed = before - after
      return if added.empty? && removed.empty?

      @role.permission_audit_events.create!(
        actor: @actor, added_permission_codes: added.sort, removed_permission_codes: removed.sort
      )
    end
  end
end

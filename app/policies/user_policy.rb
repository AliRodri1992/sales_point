# frozen_string_literal: true

class UserPolicy < CatalogPolicy
  self.permission_prefix = 'users'

  def create?
    permitted_action?(:create) && (administrator? || user.permission?('users.invite'))
  end

  def update?(account = record)
    permitted_action?(:update) && editable_account?(account)
  end

  def destroy?(account = record)
    return false unless permitted_action?(:destroy) && user.permission?('users.destroy')

    manageable_status_target?(account) && account != user
  end

  def manage_status?
    status_actor? && manageable_status_target? && record != user
  end

  def resend_invitation?
    permitted_action?(:resend_invitation) && user.permission?('users.resend_invitation') && editable_account?
  end

  class Scope < ApplicationPolicy::Scope
    USER_ACTIONS = (GranularPermissionCatalog::ACTIONS - ['access'] +
                    %w[invite resend_invitation suspend reactivate block unblock]).freeze

    def resolve
      codes = USER_ACTIONS.map { |action| "users.#{action}" }
      return scope.none unless user
      return scope.not_deleted if user.admin?

      allowed = user.permission?('users.access') && codes.any? { |code| user.permission?(code) }
      allowed ? scope.not_deleted : scope.none
    end
  end

  private

  def editable_account?(account = record)
    return true unless account.is_a?(User) && account.persisted?
    return false if administrative_account?(account) && !user.role?('super_admin')
    return true if administrator?

    account != user && single_organization?(account)
  end

  def manageable_status_target?(account = record)
    return false unless editable_account?(account)
    return true unless account.is_a?(User) && administrative_account?(account)

    user.role?('super_admin') && !account.role?('super_admin')
  end

  def administrative_account?(account)
    return account.admin? unless account.association(:user_roles).loaded?

    account.user_roles.any? do |assignment|
      role = assignment.system_role
      role && assignment.deleted_at.nil? && role.deleted_at.nil? && role.active? &&
        local_administrative_grant?(assignment) &&
        SystemRole::ADMINISTRATIVE_CODES.include?(role.code)
    end
  end

  def local_administrative_grant?(assignment)
    organization = CurrentOrganizationAccess.organization
    organization.nil? || assignment.organization_id == organization.id
  end

  def single_organization?(account)
    return account.organization_memberships.active.one? unless account.association(:organization_memberships).loaded?

    account.organization_memberships.one? { |membership| membership.active? && membership.deleted_at.nil? }
  end

  def status_actor?
    user.present? && (administrator? || (user.permission?('users.access') && status_permissions?))
  end

  def status_permissions?
    %w[suspend reactivate block unblock destroy].any? { |action| user.permission?("users.#{action}") }
  end
end

# frozen_string_literal: true

class EmailSettingAuditPolicy < ApplicationPolicy
  def index?
    user&.active? && user.admin? && user.permission?('email_setting_audits.view')
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless EmailSettingAuditPolicy.new(user, scope).index?

      ids = user.organization_memberships.accessible.select(:organization_id)
      accessible = scope.where(organization_id: ids)
      user.role?('super_admin') ? accessible.or(scope.where(organization_id: nil)) : accessible
    end
  end
end

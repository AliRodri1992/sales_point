# frozen_string_literal: true

class EmailSenderSettingPolicy < ApplicationPolicy
  def edit?
    update?
  end

  def update?
    return false unless user&.active? && user.admin? && user.permission?('email_settings.manage')
    return user.role?('super_admin') if record.organization_id.nil?

    user.organization_memberships.accessible.exists?(organization_id: record.organization_id)
  end
end

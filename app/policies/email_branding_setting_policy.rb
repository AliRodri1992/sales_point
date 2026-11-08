# frozen_string_literal: true

class EmailBrandingSettingPolicy < ApplicationPolicy
  def edit?
    update?
  end

  def update?
    return false unless user&.active? && user.admin?
    return user.role?('super_admin') && user.permission?('email_settings.manage') if record.organization_id.nil?

    user.permission?('email_branding.manage') && member_of_organization?
  end

  private

  def member_of_organization?
    user.organization_memberships.accessible.exists?(organization_id: record.organization_id)
  end
end

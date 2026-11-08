# frozen_string_literal: true

class EmailBrandingSettingPolicy < ApplicationPolicy
  def edit?
    update?
  end

  def update?
    return false unless user&.active? && user.admin?

    if record.organization_id.nil?
      user.role?('super_admin') && user.permission?('email_settings.manage')
    else
      user.permission?('email_branding.manage') &&
        user.organization_memberships.accessible.exists?(organization_id: record.organization_id)
    end
  end
end

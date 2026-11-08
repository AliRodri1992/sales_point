# frozen_string_literal: true

class EmailSenderSettingPolicy < ApplicationPolicy
  def edit?
    update?
  end

  def update?
    user&.active? && user.admin? && user.permission?('email_settings.manage') &&
      record.organization_id.present? &&
      user.organization_memberships.accessible.exists?(organization_id: record.organization_id)
  end
end

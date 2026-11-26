class IncidentPolicy < ApplicationPolicy
  MANAGEMENT_ROLES = (SystemRole::ADMINISTRATIVE_CODES + ['support']).freeze

  def create?
    user.present? && record.reporter_id == user.id
  end

  def show?
    record.reporter_id == user.id || manage?
  end

  def manage?
    record.organization.present? && user.organization_role?(MANAGEMENT_ROLES, organization: record.organization)
  end
end

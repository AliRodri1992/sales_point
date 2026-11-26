class IncidentPolicy < ApplicationPolicy
  def create?
    user.present? && record.reporter_id == user.id
  end

  def show?
    record.reporter_id == user.id || manage?
  end

  def manage?
    user.admin? && user.organizations.exists?(record.organization_id)
  end
end

# frozen_string_literal: true

class OnboardingPolicy < ApplicationPolicy
  def show?
    admin? && active_organization?
  end

  def update?
    admin? && active_organization?
  end

  def reset?
    admin? && active_organization?
  end

  private

  def admin?
    user&.admin?
  end

  def active_organization?
    user.organization_memberships.active.joins(:organization)
        .where(organizations: { deleted_at: nil }).exists?
  end
end

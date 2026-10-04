# frozen_string_literal: true

class OnboardingPolicy < ApplicationPolicy
  def show?
    admin? && user.organizations.active_records.exists?
  end

  def reset?
    admin? && user.organizations.active_records.exists?
  end

  private

  def admin?
    user&.admin?
  end
end

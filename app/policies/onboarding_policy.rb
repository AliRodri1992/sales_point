# frozen_string_literal: true

class OnboardingPolicy < ApplicationPolicy
  def show?
    user&.admin? && user.organizations.active_records.exists?
  end
end

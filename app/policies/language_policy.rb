# frozen_string_literal: true

class LanguagePolicy < ApplicationPolicy
  def index?
    access?
  end

  def show?
    access?
  end

  def create?
    access?
  end

  def update?
    access?
  end

  def destroy?
    access?
  end

  def generate?
    access?
  end

  def retry_generation?
    access?
  end

  def resume_generation?
    access?
  end

  def cancel_generation?
    access?
  end

  def really_destroy?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.not_deleted
    end
  end

  private

  def access?
    admin? || user&.permission?('languages.access')
  end

  def admin?
    user&.admin?
  end
end

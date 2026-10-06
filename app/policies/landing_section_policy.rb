# frozen_string_literal: true

class LandingSectionPolicy < ApplicationPolicy
  def index?
    delta_owner?
  end

  def update?
    delta_owner?
  end

  def toggle?
    delta_owner?
  end

  def move_up?
    delta_owner?
  end

  def move_down?
    delta_owner?
  end

  def reorder?
    delta_owner?
  end

  private

  def delta_owner?
    user&.delta? && user.admin?
  end
end

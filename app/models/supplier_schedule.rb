# frozen_string_literal: true

class SupplierSchedule < ApplicationRecord
  belongs_to :supplier
  belongs_to :branch
  validates :kind, inclusion: { in: %w[visit order delivery] }
  validates :weekday, numericality: { only_integer: true, in: 0..6 }
  validates :starts_at, presence: true
  validate :same_organization

  private

  def same_organization
    return if supplier.blank? || branch.blank?

    errors.add(:branch, :invalid) unless branch.organization_id == supplier.organization_id
  end
end

# frozen_string_literal: true

class SupplierSchedule < ApplicationRecord
  KINDS = %w[visit order delivery].freeze
  belongs_to :supplier
  belongs_to :branch
  validates :kind, inclusion: { in: KINDS }
  validates :weekday, numericality: { only_integer: true, in: 0..6 }
  validates :starts_at, presence: true
  validates :notes, length: { maximum: 1000 }, allow_blank: true
  validate :same_organization
  validate :valid_time_range

  private

  def valid_time_range
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, :invalid) if ends_at <= starts_at
  end

  def same_organization
    return if supplier.blank? || branch.blank?

    errors.add(:branch, :invalid) unless branch.organization_id == supplier.organization_id
  end
end

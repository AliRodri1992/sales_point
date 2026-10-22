# frozen_string_literal: true

class SupplierSchedule < ApplicationRecord
  has_paper_trail

  scope :not_deleted, -> { where(deleted_at: nil) }

  KINDS = %w[visit order delivery].freeze
  belongs_to :supplier
  belongs_to :branch
  validates :kind, inclusion: { in: KINDS }
  validates :weekday, numericality: { only_integer: true, in: 0..6 }
  validates :starts_at, presence: true
  validates :notes, length: { maximum: 1000 }, allow_blank: true
  validate :same_organization
  validate :valid_time_range
  validate :non_overlapping_time_slots

  def occurs_on?(date)
    return false unless weekday == date.wday
    return true unless supplier&.persisted?

    !supplier.supplier_schedule_exceptions.where(starts_on: ..date)
             .where('COALESCE(ends_on, starts_on) >= ?', date)
             .exists?(branch_id: [nil, branch_id], supplier_schedule_id: [nil, id])
  end

  def restore_safely
    return false if deleted_at.nil?

    self.deleted_at = nil
    return true if save

    self.deleted_at = deleted_at_in_database
    false
  rescue ActiveRecord::RecordNotUnique
    self.deleted_at = deleted_at_in_database
    errors.add(:base, :taken)
    false
  end

  private

  def valid_time_range
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, :invalid) if ends_at <= starts_at
  end

  def non_overlapping_time_slots
    errors.add(:starts_at, :taken) if Suppliers::ScheduleConflict.new(self).exists?
  end

  def same_organization
    return if supplier.blank? || branch.blank?

    errors.add(:branch, :invalid) unless branch.organization_id == supplier.organization_id
  end
end

# frozen_string_literal: true

class SupplierScheduleException < ApplicationRecord
  REASONS = %w[holiday suspension exception].freeze

  has_paper_trail
  belongs_to :supplier
  belongs_to :branch, optional: true
  belongs_to :supplier_schedule, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :starts_on, presence: true
  validates :reason, inclusion: { in: REASONS }
  validates :notes, length: { maximum: 1000 }, allow_blank: true
  validate :dates_in_order
  validate :belongs_to_supplier

  private

  def dates_in_order
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, :invalid) if ends_on < starts_on || ends_on > starts_on + 366.days
  end

  def belongs_to_supplier
    return unless supplier

    errors.add(:branch, :invalid) if branch && branch.organization_id != supplier.organization_id
    validate_schedule_scope if supplier_schedule
  end

  def validate_schedule_scope
    same_supplier = supplier_schedule.supplier_id == supplier.id
    same_branch = branch_id.nil? || branch_id == supplier_schedule.branch_id
    errors.add(:supplier_schedule, :invalid) unless same_supplier && same_branch
  end
end

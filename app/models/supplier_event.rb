# frozen_string_literal: true

class SupplierEvent < ApplicationRecord
  KINDS = %w[visit order delivery other].freeze
  STATUSES = %w[scheduled completed cancelled].freeze

  has_paper_trail
  belongs_to :supplier
  belongs_to :branch
  belongs_to :created_by, class_name: 'User', optional: true

  scope :not_deleted, -> { where(deleted_at: nil) }

  validates :title, presence: true, length: { maximum: 150 }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :starts_at, presence: true
  validates :notes, length: { maximum: 1000 }, allow_blank: true
  validate :valid_time_range
  validates :ends_at, presence: true, if: :all_day?
  validate :branch_in_supplier_organization
  validate :available_supplier_on_creation, on: :create

  def occurs_on?(date)
    settings = supplier.organization.organization_settings.active_records
    timezone_name = settings.pick(:timezone)
    zone = ActiveSupport::TimeZone[timezone_name] if timezone_name.present?
    zone ||= Time.zone
    first_day = starts_at.in_time_zone(zone).to_date
    last_day = (ends_at ? ends_at - Rational(1, 1_000_000) : starts_at).in_time_zone(zone).to_date
    date.between?(first_day, [first_day, last_day].max)
  end

  private

  def available_supplier_on_creation
    return if supplier&.active? && supplier.deleted_at.nil?

    errors.add(:supplier, :invalid)
  end

  def valid_time_range
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, :invalid) unless ends_at > starts_at
  end

  def branch_in_supplier_organization
    return if supplier.blank? || branch.blank?

    errors.add(:branch, :invalid) unless supplier.organization_id == branch.organization_id
  end
end

# frozen_string_literal: true

class UnitOfMeasure < ApplicationRecord
  self.table_name = 'units_of_measure'
  has_paper_trail

  belongs_to :organization
  belongs_to :sat_unit_key

  enum :status, { active: 'active', inactive: 'inactive' }, default: :active, validate: true

  normalizes :code, with: ->(value) { value.strip.upcase }
  normalizes :name, with: ->(value) { value.strip }
  normalizes :abbreviation, with: ->(value) { value.strip }
  normalizes :description, with: ->(value) { value.strip.presence }

  validates :organization, presence: true
  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 20 },
                   format: { with: /\A[A-Z0-9_]+\z/ },
                   uniqueness: { scope: :organization_id, case_sensitive: false,
                                 conditions: -> { where(deleted_at: nil) } }
  validates :abbreviation, presence: true, length: { maximum: 12 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :decimal_precision, inclusion: { in: 0..6 }

  validate :sat_unit_key_is_current, if: -> { new_record? || will_save_change_to_sat_unit_key_id? }

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :for_organization, ->(organization) { where(organization_id: organization&.id) }

  def allows_fractions?
    decimal_precision.to_i.positive?
  end

  private

  def sat_unit_key_is_current
    return if sat_unit_key.blank?
    return if SatUnitKey.current.where(id: sat_unit_key_id).exists?

    errors.add(:sat_unit_key, I18n.t('admin.units_of_measure.validation.sat_invalid'))
  end
end

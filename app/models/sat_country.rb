# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog; historical records remain available with_deleted.
class SatCountry < ApplicationRecord
  has_many :states, class_name: 'SatState', foreign_key: :country_code, primary_key: :code, inverse_of: :country

  scope :active, -> { where(status: true) }
  scope :valid_on, ->(date = Date.current) {
    where('(valid_from IS NULL OR valid_from <= :date) AND (valid_to IS NULL OR valid_to >= :date)', date: date)
  }
  scope :current, -> { active.valid_on }

  validates :code, :description, presence: true
  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :code, format: { with: /\A[A-Z]{3}\z/ }
  validate :valid_date_range

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) && (valid_to.nil? || valid_to >= date)
  end

  private

  def valid_date_range
    errors.add(:valid_to, 'must be on or after valid_from') if valid_from && valid_to && valid_to < valid_from
  end
  end

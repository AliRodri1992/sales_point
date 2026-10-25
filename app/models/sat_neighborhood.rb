# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog; historical records remain available with_deleted.
class SatNeighborhood < ApplicationRecord
  belongs_to :postal_code_catalog, class_name: 'SatPostalCode', foreign_key: :postal_code, primary_key: :code, inverse_of: :neighborhoods, optional: true

  scope :active, -> { where(status: true) }
  scope :valid_on, ->(date = Date.current) {
    where('(valid_from IS NULL OR valid_from <= :date) AND (valid_to IS NULL OR valid_to >= :date)', date: date)
  }
  scope :current, -> { active.valid_on }

  validates :code, :description, presence: true
  validates :code, uniqueness: { scope: :postal_code, conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :postal_code, presence: true, format: { with: /\A\d{5}\z/ }
  validate :valid_date_range

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) && (valid_to.nil? || valid_to >= date)
  end

  private

  def valid_date_range
    errors.add(:valid_to, 'must be on or after valid_from') if valid_from && valid_to && valid_to < valid_from
  end
  end

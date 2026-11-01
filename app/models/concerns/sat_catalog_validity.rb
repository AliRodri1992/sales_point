# frozen_string_literal: true

# Shared SAT catalog validity rules, preserving historical soft-deleted keys.
module SatCatalogValidity
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(status: true) }
    scope :valid_on, lambda { |date = Date.current|
      where('(valid_from IS NULL OR valid_from <= :date) AND (valid_to IS NULL OR valid_to >= :date)', date: date)
    }
    scope :current, -> { active.valid_on }

    validates :status, inclusion: { in: [true, false] }
    validate :valid_date_range
  end

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) && (valid_to.nil? || valid_to >= date)
  end

  private

  def valid_date_range
    return if valid_from.nil? || valid_to.nil?

    errors.add(:valid_to, 'must be on or after valid_from') if valid_to < valid_from
  end
end

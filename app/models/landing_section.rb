# frozen_string_literal: true

class LandingSection < ApplicationRecord
  KEYS = %w[
    hero
    benefits
    modules
    how_it_works
    screenshots
    security
    testimonials
    faq
    cta
    pricing
  ].freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }
  validates :position, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }

  scope :ordered, -> { order(:position) }
  scope :enabled, -> { where(enabled: true) }
end

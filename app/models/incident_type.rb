class IncidentType < ApplicationRecord
  DEFAULT_CODES = %w[function data display access performance other].freeze
  scope :available, -> { where(active: true).order(:id) }
end

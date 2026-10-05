# frozen_string_literal: true

class DashboardPreference < ApplicationRecord
  belongs_to :user

  validates :grid_type, presence: true
  validates :widget_id, presence: true

  validates :position_x,
            :position_y,
            :width,
            :height,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }

  validates :grid_type,
            inclusion: {
              in: %w[kpi main]
            }

  validates :widget_id,
            uniqueness: {
              scope: :user_id
            }
end

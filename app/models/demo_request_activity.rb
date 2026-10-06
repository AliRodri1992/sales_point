# frozen_string_literal: true

class DemoRequestActivity < ApplicationRecord
  ACTIONS = %w[created status_changed assigned].freeze

  belongs_to :demo_request
  belongs_to :user, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
end

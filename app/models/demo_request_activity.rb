# frozen_string_literal: true

class DemoRequestActivity < ApplicationRecord
  ACTIONS = %w[created status_changed assigned note_added reminder_sent].freeze

  belongs_to :demo_request
  belongs_to :user, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
end

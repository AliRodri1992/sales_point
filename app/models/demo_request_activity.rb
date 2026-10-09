# frozen_string_literal: true

class DemoRequestActivity < ApplicationRecord
  ACTIONS = %w[
    created
    status_changed
    assigned
    note_added
    contact_registered
    follow_up_scheduled
    demo_outcome_recorded
    converted
    reminder_sent
    confirmation_sent
  ].freeze

  belongs_to :demo_request
  belongs_to :user, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
end

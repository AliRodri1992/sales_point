# frozen_string_literal: true

module Users
  # Renders internal lifecycle errors as localized, user-friendly messages.
  module StatusErrorPresenter
    ERROR_KEYS = {
      'Cannot disable the last administrator' => 'last_administrator',
      'Transition not permitted' => 'transition_not_permitted',
      'Reason required' => 'reason_required',
      'Incident resolution required' => 'resolution_required',
      'Security incident not found' => 'incident_not_found',
      'Review date must be in the future' => 'review_date_future'
    }.freeze

    def self.call(message)
      key = ERROR_KEYS.fetch(message, 'unexpected')
      I18n.t("admin.users.status_management.errors.#{key}")
    end
  end
end

# frozen_string_literal: true

module Admin
  # Uses the same synchronous Noticed delivery as branch and supplier actions.
  module EmailSettingActivity
    private

    def notify_email_setting(action, setting)
      EmailSettingNotification.with(action:, record: setting, user: current_user)
                              .deliver(current_user, enqueue_job: false)
      current_user.broadcast_notifications_refresh
    rescue StandardError => e
      Rails.logger.error("Email notification delivery failed: #{e.class}")
    end
  end
end

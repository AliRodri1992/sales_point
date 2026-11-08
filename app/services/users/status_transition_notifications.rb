# frozen_string_literal: true

module Users
  # Sends audit-related notices after a successful status transition.
  module StatusTransitionNotifications
    private

    def notify_account_holder
      EmailTemplate.ensure_status_template!
      UserStatusMailer.changed(@status_event.id).deliver_later
      return if @user.deleted?

      UserStatusNotification.with(record: @user, action: @target, user: @actor)
                            .deliver(@user, enqueue_job: false)
    rescue StandardError => e
      Rails.logger.error("User status notification failed: #{e.class}")
    end
  end
end

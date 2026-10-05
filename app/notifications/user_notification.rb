# frozen_string_literal: true

class UserNotification < Noticed::Event
  required_param :action
  required_param :user

  def action
    params[:action] || 'updated'
  end

  # The user who triggered the action (the logged-in user in the session).
  def user
    params[:user]
  end

  # Users are soft-deletable (paranoia), so a destroyed user is hidden from
  # the default scope. Keep it reachable for the notification UI.
  def record
    super || User.with_deleted.find_by(id: record_id)
  end

  # Human-readable description used by the notifications list and by any
  # delivery method (email, SMS, ...) that needs a summary string.
  def message
    t("admin.shared.notifications.user.#{action}",
      name: record.display_name,
      user: user.display_name,
      default: record.display_name)
  end
end

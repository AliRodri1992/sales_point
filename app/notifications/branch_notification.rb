# frozen_string_literal: true

class BranchNotification < Noticed::Event
  required_param :action
  required_param :user

  delegate :name, to: :record

  def action
    params[:action] || 'updated'
  end

  # The user who triggered the action (the logged-in user in the session).
  def user
    params[:user]
  end

  # Human-readable description used by the notifications list and by
  # any delivery method (email, SMS, …) that needs a summary string.
  def message
    t("admin.shared.notifications.branch.#{action}",
      name: record.name,
      user: user.display_name,
      default: record.name)
  end
end

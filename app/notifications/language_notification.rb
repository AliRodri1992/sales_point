# frozen_string_literal: true

class LanguageNotification < Noticed::Event
  required_param :action
  required_param :user

  delegate :name, :code, :flag_iso, to: :record

  def action
    params[:action] || 'updated'
  end

  # The user who triggered the action (the logged-in user in the session).
  def user
    params[:user]
  end

  # Override the polymorphic record association so soft-deleted
  # languages (removed via acts_as_paranoid) are still visible in
  # the notification list. The default belongs_to uses the paranoid
  # default scope (WHERE deleted_at IS NULL), which filters them out.
  def record
    super || Language.with_deleted.find_by(id: record_id)
  end

  # Human-readable description used by the notifications list and by
  # any delivery method (email, SMS, …) that needs a summary string.
  def message
    t("admin.shared.notifications.language.#{action}",
      name: record.name,
      default: record.name)
  end
end

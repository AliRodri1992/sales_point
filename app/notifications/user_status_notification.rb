# frozen_string_literal: true

class UserStatusNotification < Noticed::Event
  required_param :action
  required_param :user

  def action
    params[:action]
  end

  def record
    super || User.with_deleted.find_by(id: record_id)
  end

  def message
    t("admin.users.status_management.notification_#{action}", default: record&.display_name)
  end
end

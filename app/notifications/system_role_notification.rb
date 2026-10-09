# frozen_string_literal: true

class SystemRoleNotification < Noticed::Event
  required_param :action
  required_param :user

  delegate :name, :code, to: :record

  def action
    params[:action] || 'updated'
  end

  def user
    params[:user]
  end

  # SystemRole is paranoid, so a deprecated role would be hidden by the
  # default scope and the notification would lose its record.
  def record
    super || SystemRole.with_deleted.find_by(id: record_id)
  end

  def message
    t("admin.shared.notifications.system_role.#{action}",
      name: record.name,
      default: record.name)
  end
end

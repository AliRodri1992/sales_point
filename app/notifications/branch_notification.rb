# frozen_string_literal: true

class BranchNotification < Noticed::Event
  required_param :action
  required_param :user

  delegate :name, to: :record

  def action
    params[:action] || 'updated'
  end

  def user
    params[:user]
  end

  def message
    t("admin.shared.notifications.branch.#{action}",
      name: record.name,
      default: record.name)
  end
end

# frozen_string_literal: true

class BranchNotification < Noticed::Event
  required_params :action, :user, :user_name

  delegate :name, to: :record

  def action
    params[:action] || 'updated'
  end

  def user
    params[:user]
  end

  def user_name
    params[:user_name].presence || user&.display_name
  end

  notification_methods do
    def message
      t("admin.shared.notifications.branch.#{params[:action]}",
        name: record.name,
        user: params[:user_name],
        default: record.name)
    end
  end
end

# frozen_string_literal: true

class EmailSettingNotification < Noticed::Event
  required_param :action
  required_param :user

  def message
    t("admin.shared.notifications.email_setting.#{params[:action]}")
  end
end

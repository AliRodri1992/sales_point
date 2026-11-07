# frozen_string_literal: true

class EmailTemplateNotification < Noticed::Event
  required_param :action
  required_param :user

  def message
    t("admin.shared.notifications.email_template.#{params[:action]}",
      name: record.name, default: record.name)
  end
end

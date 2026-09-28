# frozen_string_literal: true

class OrganizationNotification < Noticed::Event
  required_param :action
  required_param :user

  delegate :name, to: :record

  def message
    t("admin.shared.notifications.organization.#{params[:action]}",
      name: record.name,
      user: params[:user].display_name)
  end
end

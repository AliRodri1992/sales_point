# frozen_string_literal: true

class SubscriptionNotification < Noticed::Event
  required_param :action
  required_param :user

  def message
    t("admin.shared.notifications.subscription.#{params[:action]}",
      organization: record.organization.name,
      user: params[:user].display_name)
  end
end

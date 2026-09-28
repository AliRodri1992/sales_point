# frozen_string_literal: true

class MembershipPlanNotification < Noticed::Event
  required_param :action
  required_param :user

  delegate :name, to: :record

  def message
    t("admin.shared.notifications.membership_plan.#{params[:action]}",
      name: record.name,
      user: params[:user].display_name)
  end
end

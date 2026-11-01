# frozen_string_literal: true

class PurchaseNotification < Noticed::Event
  required_param :action
  required_param :user

  def message
    identifier = record.respond_to?(:code) ? record.code : "##{record.id}"
    t("admin.purchases.notifications.#{params[:action]}", name: identifier, default: identifier)
  end
end

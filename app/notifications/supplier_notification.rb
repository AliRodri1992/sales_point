# frozen_string_literal: true

class SupplierNotification < Noticed::Event
  required_param :action
  required_param :user

  delegate :name, :code, to: :record

  def action
    params[:action] || 'updated'
  end

  def user
    params[:user]
  end

  def message
    return t("admin.supplier_details.#{action}") if action.start_with?('address_')

    t("admin.shared.notifications.supplier.#{action}",
      name: record.name,
      default: record.name)
  end
end

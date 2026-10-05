# frozen_string_literal: true

class CategoryNotification < Noticed::Event
  required_param :action
  required_param :user

  delegate :name, :code, to: :record

  def action
    params[:action] || 'updated'
  end

  def user
    params[:user]
  end

  def record
    super || Category.with_deleted.find_by(id: record_id)
  end

  def message
    t("admin.shared.notifications.category.#{action}",
      name: record.name,
      default: record.name)
  end
end

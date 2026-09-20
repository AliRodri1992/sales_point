# frozen_string_literal: true

module NotificationsHelper
  def notifications_subtitle(user)
    count = user.unread_notifications.count
    return t('admin.shared.notifications.subtitle_none') if count.zero?

    t('admin.shared.notifications.subtitle', count: count)
  end

  # Noticed stores the notification class in the `type` column, e.g.
  # "ChatNotification::Notification" => "chat"
  def notification_type_label(notification)
    type = notification.type.to_s.split('::').first.to_s.delete_suffix('Notification').underscore
    return if type.blank?

    t("admin.shared.notifications.types.#{type}", default: type.humanize)
  end
end

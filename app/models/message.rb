class Message < ApplicationRecord
  acts_as_paranoid

  belongs_to :conversation
  belongs_to :user

  validates :body, presence: true

  after_create_commit :broadcast_message, :notify_recipient

  private

  def broadcast_message
    broadcast_append_to(
      conversation,
      target: 'conversation_messages',
      partial: 'messages/message'
    )
  end

  def notify_recipient
    recipient = conversation.other_user(user)
    return if recipient.nil?

    event = MessageNotification.with(message: self, record: self)
    event.deliver(recipient, enqueue_job: false)

    notification = event.notifications.find_by(recipient: recipient)
    return if notification.nil?

    Turbo::StreamsChannel.broadcast_append_to(
      "notifications_#{recipient.id}",
      target: 'notifications_list',
      partial: 'admin/shared/notification',
      locals: { notification: notification }
    )

    refresh_notifications_badge(recipient)
  end

  def refresh_notifications_badge(user)
    Turbo::StreamsChannel.broadcast_replace_to(
      "notifications_#{user.id}",
      target: 'notifications_badge',
      partial: 'admin/shared/notifications_badge',
      locals: { user: user }
    )
  end
end

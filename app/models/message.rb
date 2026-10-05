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

    event = ChatNotification.with(message: self, record: self)
    event.deliver(recipient, enqueue_job: false)

    recipient.broadcast_notifications_refresh
  end
end

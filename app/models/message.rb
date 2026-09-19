class Message < ApplicationRecord
  acts_as_paranoid

  belongs_to :conversation
  belongs_to :user

  validates :body, presence: true

  broadcasts_to ->(message) { message.conversation },
                target: 'conversation_messages',
                partial: 'messages/message',
                locals: ->(message) { { message: message } }
end

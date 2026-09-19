class ConversationParticipant < ApplicationRecord
  acts_as_paranoid

  belongs_to :conversation
  belongs_to :user

  validates :conversation_id,
            uniqueness: {
              scope: :user_id,
              conditions: -> { where(deleted_at: nil) }
            }
end

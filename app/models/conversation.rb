class Conversation < ApplicationRecord
  acts_as_paranoid

  has_many :conversation_participants, dependent: :destroy
  has_many :users, through: :conversation_participants
  has_many :messages, dependent: :destroy

  validates :conversation_type, presence: true

  DIRECT = 'direct'.freeze

  def self.find_or_create_direct(user_a, user_b)
    ids = [user_a.id, user_b.id]

    conversation_ids = ConversationParticipant
                       .where(user_id: ids)
                       .group(:conversation_id)
                       .having('COUNT(DISTINCT user_id) = 2')
                       .pluck(:conversation_id)

    existing = where(id: conversation_ids, conversation_type: DIRECT).find do |conv|
      conv.conversation_participants.count == 2
    end

    existing || create_with_participants(user_a, user_b)
  end

  def self.create_with_participants(user_a, user_b)
    transaction do
      conv = create!(conversation_type: DIRECT)
      conv.conversation_participants.create!(user_id: user_a.id)
      conv.conversation_participants.create!(user_id: user_b.id)
      conv
    end
  end

  def other_user(user)
    users.where.not(id: user.id).first
  end
end

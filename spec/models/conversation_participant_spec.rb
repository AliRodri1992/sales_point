# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationParticipant, type: :model do
  describe 'validations' do
    it 'validates uniqueness of conversation_id scoped to user_id' do
      conversation = create(:conversation)
      user = create(:user)
      create(:conversation_participant, conversation:, user:)

      duplicate = build(:conversation_participant, conversation:, user:)
      expect(duplicate).to be_invalid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:user) }
  end
end

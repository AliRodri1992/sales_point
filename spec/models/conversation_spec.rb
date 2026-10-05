# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversation, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:conversation_type) }
  end

  describe 'class methods' do
    describe '.find_or_create_direct' do
      let(:user_a) { create(:user) }
      let(:user_b) { create(:user) }

      it 'creates a new conversation if one does not exist' do
        expect { described_class.find_or_create_direct(user_a, user_b) }
          .to change(described_class, :count).by(1)
      end

      it 'returns existing conversation if it exists' do
        conv = described_class.create!(conversation_type: 'direct')
        conv.conversation_participants.create!(user_id: user_a.id)
        conv.conversation_participants.create!(user_id: user_b.id)

        result = described_class.find_or_create_direct(user_a, user_b)

        expect(result).to eq(conv)
        expect(described_class.count).to eq(1)
      end
    end

    describe '.create_with_participants' do
      let(:user_a) { create(:user) }
      let(:user_b) { create(:user) }

      it 'creates a conversation with two participants' do
        expect { described_class.create_with_participants(user_a, user_b) }
          .to change(described_class, :count).by(1)
          .and change(ConversationParticipant, :count).by(2)
      end

      it 'creates a direct conversation' do
        conv = described_class.create_with_participants(user_a, user_b)
        expect(conv.conversation_type).to eq('direct')
      end
    end
  end

  describe '#other_user' do
    let(:conversation) { create(:conversation, conversation_type: 'direct') }
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }

    before do
      conversation.conversation_participants.create!(user_id: user_a.id)
      conversation.conversation_participants.create!(user_id: user_b.id)
    end

    it 'returns the other user in the conversation' do
      other = conversation.other_user(user_a)
      expect(other).to eq(user_b)
    end
  end
end

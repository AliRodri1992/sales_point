# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Conversations', type: :request do
  let(:user) { create(:user) }
  let(:participant) { create(:user) }
  let(:conversation) { create(:conversation) }

  before do
    create(:conversation_participant, conversation:, user:)
    create(:conversation_participant, conversation:, user: participant)
    sign_in user
    allow(User).to receive(:online_user_ids).and_return([])
  end

  describe 'GET /conversations/:id' do
    it 'renders the conversation panel and its ordered messages' do
      older_message = create(:message, conversation:, user:, body: 'First message', created_at: 2.minutes.ago)
      create(:message, conversation:, user: participant, body: 'Second message', created_at: 1.minute.ago)

      get conversation_path(conversation)

      expect(response).to have_http_status(:ok)
      expect(response.body.index(older_message.body)).to be < response.body.index('Second message')
      expect(response.body).to include('conversation_panel')
    end
  end

  describe 'POST /conversations' do
    it 'creates or finds a direct conversation with the selected participant' do
      post conversations_path, params: { participant_id: participant.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('conversation_panel')
      expect(ConversationParticipant.where(user: [user, participant]).distinct.count(:conversation_id)).to eq(1)
    end
  end
end

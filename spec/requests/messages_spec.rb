# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Messages', type: :request do
  let(:user) { create(:user) }
  let(:participant) { create(:user) }
  let(:conversation) { create(:conversation) }

  before do
    create(:conversation_participant, conversation:, user:)
    create(:conversation_participant, conversation:, user: participant)
    sign_in user
  end

  describe 'POST /conversations/:conversation_id/messages' do
    it 'creates a message and returns a Turbo Stream response' do
      expect do
        post conversation_messages_path(conversation, format: :turbo_stream),
             params: { message: { body: 'Hello there' } }
      end.to change(Message, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include("new_message_form_#{conversation.id}")
    end

    it 'renders validation feedback when the body is blank' do
      expect do
        post conversation_messages_path(conversation, format: :turbo_stream),
             params: { message: { body: '' } }
      end.not_to change(Message, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('can&#39;t be blank').or include("can't be blank")
    end
  end
end

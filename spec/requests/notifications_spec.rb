# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notifications', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'POST /notifications/mark_all_read' do
    it 'marks unread notifications as read and refreshes notification streams' do
      unread_notifications = double('unread notifications', mark_as_read: true)
      allow(user).to receive(:unread_notifications).and_return(unread_notifications)
      allow(user).to receive(:broadcast_notifications_refresh)

      post mark_all_read_notifications_path, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(unread_notifications).to have_received(:mark_as_read)
      expect(user).to have_received(:broadcast_notifications_refresh)
    end
  end
end

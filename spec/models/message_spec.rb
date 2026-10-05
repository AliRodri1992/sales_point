# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  subject(:message) { build(:message) }

  describe 'validations' do
    it 'requires a body' do
      message.body = nil
      expect(message).to be_invalid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'callbacks' do
    it 'broadcasts a newly created message' do
      allow(message).to receive(:broadcast_append_to)
      message.send(:broadcast_message)
      expect(message).to have_received(:broadcast_append_to).with(message.conversation,target:'conversation_messages',partial:'messages/message')
    end

    it 'does nothing when there is no recipient' do
      allow(message.conversation).to receive(:other_user).with(message.user).and_return(nil)
      expect { message.send(:notify_recipient) }.not_to raise_error
    end

    it 'delivers a notification and refreshes the recipient' do
      recipient=create(:user); notification=instance_double(ChatNotification)
      allow(message.conversation).to receive(:other_user).with(message.user).and_return(recipient)
      allow(ChatNotification).to receive(:with).with(message:,record:message).and_return(notification)
      allow(notification).to receive(:deliver); allow(recipient).to receive(:broadcast_notifications_refresh)
      message.send(:notify_recipient)
      expect(notification).to have_received(:deliver).with(recipient,enqueue_job:false)
      expect(recipient).to have_received(:broadcast_notifications_refresh)
    end
  end
end
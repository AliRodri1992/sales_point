# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationsHelper, type: :helper do
  describe '#notifications_subtitle' do
    it 'uses the empty subtitle when there are no unread notifications' do
      user = instance_double(User, unread_notifications: double(count: 0))

      expect(helper).to receive(:t).with('admin.shared.notifications.subtitle_none')
        .and_return('No unread notifications')

      expect(helper.notifications_subtitle(user)).to eq('No unread notifications')
    end

    it 'includes the unread notification count' do
      user = instance_double(User, unread_notifications: double(count: 3))

      expect(helper).to receive(:t).with('admin.shared.notifications.subtitle', count: 3)
        .and_return('3 unread notifications')

      expect(helper.notifications_subtitle(user)).to eq('3 unread notifications')
    end
  end

  describe '#notification_type_label' do
    it 'translates a notification type derived from its class name' do
      notification = instance_double(ActiveRecord::Base, type: 'ChatNotification::Notification')

      expect(helper).to receive(:t).with(
        'admin.shared.notifications.types.chat',
        default: 'Chat'
      ).and_return('Chat')

      expect(helper.notification_type_label(notification)).to eq('Chat')
    end

    it 'returns nil when the notification type is blank' do
      notification = instance_double(ActiveRecord::Base, type: nil)

      expect(helper.notification_type_label(notification)).to be_nil
    end
  end
end

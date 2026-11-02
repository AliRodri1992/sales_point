# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationsHelper, type: :helper do
  describe '#notifications_subtitle' do
    it 'uses the empty subtitle when there are no unread notifications' do
      user = instance_double(User, unread_notifications: double(count: 0))

      translation = 'No unread notifications'
      expect(helper).to receive(:t).with('admin.shared.notifications.subtitle_none').and_return(translation)

      expect(helper.notifications_subtitle(user)).to eq('No unread notifications')
    end

    it 'includes the unread notification count' do
      user = instance_double(User, unread_notifications: double(count: 3))

      translation = '3 unread notifications'
      expect(helper).to receive(:t).with('admin.shared.notifications.subtitle', count: 3).and_return(translation)

      expect(helper.notifications_subtitle(user)).to eq('3 unread notifications')
    end
  end

  describe 'localized unread counts' do
    it 'uses singular and plural notification labels in Spanish and English' do
      { es: ['1 notificación sin leer', '2 notificaciones sin leer'],
        en: ['1 unread notification', '2 unread notifications'] }.each do |locale, expected|
        I18n.with_locale(locale) do
          expected.each_with_index do |label, index|
            user = instance_double(User, unread_notifications: double(count: index + 1))
            expect(helper.notifications_subtitle(user)).to eq(label)
          end
        end
      end
    end
  end

  describe '#notification_type_label' do
    it 'translates a notification type derived from its class name' do
      notification = double(type: 'ChatNotification::Notification')

      expect(helper).to receive(:t).with(
        'admin.shared.notifications.types.chat',
        default: 'Chat'
      ).and_return('Chat')

      expect(helper.notification_type_label(notification)).to eq('Chat')
    end

    it 'returns nil when the notification type is blank' do
      notification = double(type: nil)

      expect(helper.notification_type_label(notification)).to be_nil
    end
  end
end

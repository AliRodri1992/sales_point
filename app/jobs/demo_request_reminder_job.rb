# frozen_string_literal: true

class DemoRequestReminderJob < ApplicationJob
  queue_as :default

  REMINDER_TIMESTAMPS = {
    'twenty_four_hours' => 'reminder_24h_sent_at',
    'one_hour' => 'reminder_1h_sent_at'
  }.freeze

  def perform(demo_request_id, reminder_window, scheduled_at_timestamp)
    demo_request = DemoRequest.find_by(id: demo_request_id)
    return unless valid_reminder?(demo_request, scheduled_at_timestamp)

    send_reminder(demo_request, reminder_window)
  end

  private

  def valid_reminder?(demo_request, scheduled_at_timestamp)
    demo_request&.scheduled? &&
      demo_request.scheduled_at.present? &&
      demo_request.scheduled_at.to_i == scheduled_at_timestamp.to_i
  end

  def send_reminder(demo_request, reminder_window)
    timestamp_attr = REMINDER_TIMESTAMPS.fetch(reminder_window)
    return if demo_request.public_send(timestamp_attr).present?

    DemoRequestDeliveryService.call(demo_request, reminder_window)
    demo_request.update({ timestamp_attr => Time.current }, validate: false)
  end
end

# frozen_string_literal: true

class DemoRequestReminderJob < ApplicationJob
  queue_as :default

  def perform(demo_request_id, reminder_window)
    demo_request = DemoRequest.find_by(id: demo_request_id)
    return unless demo_request&.scheduled?
    return if demo_request.scheduled_at.blank?

    send_reminder(demo_request, reminder_window)
  end

  private

  def send_reminder(demo_request, reminder_window)
    timestamp_attribute = { 'twenty_four_hours' => 'reminder_24h_sent_at', 'one_hour' => 'reminder_1h_sent_at' }.fetch(reminder_window)
    return if demo_request.public_send(timestamp_attribute).present?

    DemoRequestMailer.with(
      demo_request: demo_request,
      locale: demo_request.locale
    ).reminder(reminder_window).deliver_now

    demo_request.update_column(timestamp_attribute, Time.current)
    demo_request.activities.create!(
      action: 'reminder_sent',
      details: I18n.with_locale(demo_request.locale) do
        I18n.t("demo_request_mailer.reminder.activity.#{reminder_window}")
      end
    )
  end
end

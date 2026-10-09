# frozen_string_literal: true

module DemoRequests
  class Reminders
    def initialize(demo_request, current_user)
      @demo_request = demo_request
      @current_user = current_user
    end

    def reset_if_rescheduled
      return unless @demo_request.saved_change_to_scheduled_at?

      @demo_request.update!(
        reminder_24h_sent_at: nil,
        reminder_1h_sent_at: nil
      )
    end

    def schedule(previous_status)
      return unless @demo_request.scheduled?
      return if @demo_request.scheduled_at.blank?
      return if previous_status == 'scheduled' && !@demo_request.saved_change_to_scheduled_at?

      schedule_reminder('twenty_four_hours', 24.hours)
      schedule_reminder('one_hour', 1.hour)
    end

    def send_confirmation(previous_status)
      return unless @demo_request.scheduled?
      return if previous_status == 'scheduled' && !@demo_request.saved_change_to_scheduled_at?

      send_scheduled_email
      record_confirmation_activity
    end

    private

    def schedule_reminder(window, interval)
      run_at = @demo_request.scheduled_at - interval
      return if run_at <= Time.current

      DemoRequestReminderJob
        .set(wait_until: run_at)
        .perform_later(@demo_request.id, window.to_s, @demo_request.scheduled_at.to_i)
    end

    def send_scheduled_email
      DemoRequestMailer.with(
        demo_request: @demo_request,
        locale: @demo_request.locale
      ).scheduled.deliver_later
    end

    def record_confirmation_activity
      @demo_request.activities.create!(
        user: @current_user,
        action: 'confirmation_sent',
        details: I18n.t('demo_request_mailer.scheduled.activity')
      )
    end
  end
end

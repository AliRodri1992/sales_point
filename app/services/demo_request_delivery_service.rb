# frozen_string_literal: true

class DemoRequestDeliveryService
  def self.call(demo_request, reminder_window)
    DemoRequestMailer.with(
      demo_request: demo_request,
      locale: demo_request.locale
    ).reminder(reminder_window).deliver_now
  end
end

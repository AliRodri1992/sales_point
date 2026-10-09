# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequestReminderJob, type: :job do
  let(:demo_request) do
    create(:demo_request, status: :scheduled, scheduled_at: 2.hours.from_now)
  end

  it 'sends the reminder and records the delivery' do
    message_delivery = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    mailer = DemoRequestMailer.with(demo_request: demo_request, locale: demo_request.locale)
    allow(mailer).to receive(:reminder).with('one_hour').and_return(message_delivery)
    allow(DemoRequestMailer).to receive(:with).with(
      demo_request: demo_request,
      locale: demo_request.locale
    ).and_return(mailer)

    expect do
      described_class.perform_now(demo_request.id, 'one_hour', demo_request.scheduled_at.to_i)
    end.to change { demo_request.reload.reminder_1h_sent_at }.from(nil)

    expect(DemoRequestMailer).to have_received(:with).with(
      demo_request: demo_request,
      locale: demo_request.locale
    )
    expect(demo_request.activities.where(action: 'reminder_sent')).to exist
  end

  it 'does not send a duplicate reminder' do
    demo_request.update!(reminder_1h_sent_at: Time.current)
    expect(DemoRequestMailer).not_to receive(:with)

    described_class.perform_now(demo_request.id, 'one_hour', demo_request.scheduled_at.to_i)
  end

  it 'does not send reminders for cancelled requests' do
    demo_request.update!(status: :cancelled)
    expect(DemoRequestMailer).not_to receive(:with)

    described_class.perform_now(demo_request.id, 'one_hour', demo_request.scheduled_at.to_i)
  end
end

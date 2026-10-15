# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Demo reminder lifecycle decision paths', type: :service do
  let(:scheduled_at) { 48.hours.from_now }
  let(:request) { double(id: 10, scheduled_at:, locale: 'es') }
  let(:service) { DemoRequests::Reminders.new(request, double('User')) }

  it 'does not reset reminders if the schedule was unchanged' do
    allow(request).to receive(:saved_change_to_scheduled_at?).and_return(false)
    expect(request).not_to receive(:update!)
    service.reset_if_rescheduled
  end

  it 'resets both reminder timestamps when rescheduled' do
    allow(request).to receive(:saved_change_to_scheduled_at?).and_return(true)
    allow(request).to receive(:update!)
    service.reset_if_rescheduled
    expect(request).to have_received(:update!).with(reminder_24h_sent_at: nil, reminder_1h_sent_at: nil)
  end

  it 'skips scheduling for draft requests' do
    allow(request).to receive(:scheduled?).and_return(false)
    expect(service).not_to receive(:schedule_reminder)
    service.schedule('draft')
  end

  it 'skips scheduling if no appointment time exists' do
    allow(request).to receive_messages(scheduled?: true, scheduled_at: nil)
    expect(service).not_to receive(:schedule_reminder)
    service.schedule('draft')
  end

  it 'skips unchanged previously scheduled appointments' do
    allow(request).to receive_messages(scheduled?: true, saved_change_to_scheduled_at?: false)
    expect(service).not_to receive(:schedule_reminder)
    service.schedule('scheduled')
  end

  it 'reschedules both notifications if the appointment time changed' do
    allow(request).to receive_messages(scheduled?: true, saved_change_to_scheduled_at?: true)
    allow(service).to receive(:schedule_reminder)
    service.schedule('scheduled')
    expect(service).to have_received(:schedule_reminder).twice
  end

  it 'does not send confirmation to non-scheduled requests' do
    allow(request).to receive(:scheduled?).and_return(false)
    expect(service).not_to receive(:send_scheduled_email)
    service.send_confirmation('draft')
  end

  it 'does not duplicate confirmations when the schedule is unchanged' do
    allow(request).to receive_messages(scheduled?: true, saved_change_to_scheduled_at?: false)
    expect(service).not_to receive(:send_scheduled_email)
    service.send_confirmation('scheduled')
  end

  it 'sends confirmation and records activity when newly scheduled' do
    allow(request).to receive(:scheduled?).and_return(true)
    allow(service).to receive(:send_scheduled_email)
    allow(service).to receive(:record_confirmation_activity)
    service.send_confirmation('draft')
    expect(service).to have_received(:send_scheduled_email).once
    expect(service).to have_received(:record_confirmation_activity).once
  end

  it 'does not enqueue reminders whose due time has passed' do
    allow(request).to receive(:scheduled_at).and_return(1.hour.ago)
    expect(DemoRequestReminderJob).not_to receive(:set)
    service.send(:schedule_reminder, 'one_hour', 1.hour)
  end

  it 'enqueues future reminders with the scheduled timestamp' do
    delivery = double('Scheduled reminder')
    allow(delivery).to receive(:perform_later)
    allow(DemoRequestReminderJob).to receive(:set).and_return(delivery)
    service.send(:schedule_reminder, 'one_hour', 1.hour)
    expect(delivery).to have_received(:perform_later).with(10, 'one_hour', scheduled_at.to_i)
  end
end

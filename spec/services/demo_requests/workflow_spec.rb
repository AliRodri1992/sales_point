# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequests::Workflow, type: :service do
  let(:actor) { instance_double(User) }
  let(:activities) { double('activities') }
  let(:demo_request) do
    instance_double(
      DemoRequest,
      status: current_status,
      assigned_to_id: current_assignee_id,
      assigned_to: assignee,
      activities:
    )
  end
  let(:current_status) { 'pending' }
  let(:current_assignee_id) { nil }
  let(:assignee) { nil }
  let(:reminders) { instance_double(DemoRequests::Reminders, reset_if_rescheduled: nil, schedule: nil, send_confirmation: nil) }
  let(:commercial_activities) { instance_double(DemoRequests::Activities, record_all: nil) }

  before do
    allow(DemoRequests::Reminders).to receive(:new).and_return(reminders)
    allow(DemoRequests::Activities).to receive(:new).and_return(commercial_activities)
  end

  it 'skips workflow activity and assignee notification when nothing changed' do
    allow(activities).to receive(:create!)
    expect(DemoRequestMailer).not_to receive(:with)

    described_class.new(demo_request, actor, 'pending', nil).call

    expect(activities).not_to have_received(:create!)
    expect(reminders).to have_received(:reset_if_rescheduled)
    expect(reminders).to have_received(:schedule).with('pending')
    expect(reminders).to have_received(:send_confirmation).with('pending')
    expect(commercial_activities).to have_received(:record_all)
  end

  it 'records a status transition when the assignee stays the same' do
    allow(activities).to receive(:create!)
    request = demo_request
    allow(request).to receive(:status).and_return('scheduled')

    described_class.new(request, actor, 'pending', nil).call

    expect(activities).to have_received(:create!).with(
      user: actor,
      action: 'status_changed',
      details: { from: 'pending', to: 'scheduled' }
    )
  end

  it 'records an unassigned activity when the assignee is removed' do
    allow(activities).to receive(:create!)

    described_class.new(demo_request, actor, 'pending', 123).call

    expect(activities).to have_received(:create!).with(
      user: actor,
      action: 'assigned',
      details: { assigned_to: 'unassigned' }
    )
  end

  it 'notifies a new assignee and falls back to the current locale when they have no language' do
    new_assignee = instance_double(User, display_name: 'Ada', language: nil)
    request = instance_double(
      DemoRequest,
      status: 'pending',
      assigned_to_id: 42,
      assigned_to: new_assignee,
      activities:
    )
    delivery = double('mail delivery', deliver_later: true)
    mailer = double('demo request mailer', workflow_update: delivery)
    allow(activities).to receive(:create!)
    allow(DemoRequestMailer).to receive(:with).and_return(mailer)

    described_class.new(request, actor, 'pending', nil).call

    expect(activities).to have_received(:create!).with(
      user: actor,
      action: 'assigned',
      details: { assigned_to: 'Ada' }
    )
    expect(DemoRequestMailer).to have_received(:with).with(
      demo_request: request,
      assignee: new_assignee,
      actor: actor,
      action: 'assigned',
      locale: I18n.locale.to_s
    )
    expect(delivery).to have_received(:deliver_later)
  end
end

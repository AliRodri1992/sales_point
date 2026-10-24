# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierCalendarReminderJob do
  let(:organization) { create(:organization) }
  let(:recipient) { create(:user) }
  let(:supplier) { create(:supplier, organization:, responsible_user: recipient) }
  let(:branch) { create(:branch, organization:) }
  let(:tomorrow) { Date.current + 1 }

  before do
    create(:organization_membership, organization:, user: recipient)
    create(:user_role, user: recipient, system_role: create(:system_role, :system, code: 'administrator'))
    allow_any_instance_of(User).to receive(:broadcast_notifications_refresh)
  end

  it 'sends only one notification for each scheduled visit or delivery' do
    supplier.supplier_events.create!(
      title: 'Extra delivery', kind: 'delivery', branch:,
      starts_at: tomorrow.in_time_zone.change(hour: 9),
      ends_at: tomorrow.in_time_zone.change(hour: 11)
    )
    supplier.supplier_schedules.create!(
      branch:, kind: 'visit', weekday: tomorrow.wday,
      starts_at: '12:00', ends_at: '13:00'
    )

    expect { described_class.perform_now(Date.current) }
      .to change(SupplierEventDelivery, :count).by(2)
    expect(recipient.reload.notifications.count).to eq(2)

    expect { described_class.perform_now(Date.current) }
      .not_to change(SupplierEventDelivery, :count)
    expect(recipient.reload.notifications.count).to eq(2)
  end

  it 'does not mark an activity delivered when the notification fails' do
    supplier.supplier_events.create!(
      title: 'Retryable delivery', kind: 'delivery', branch:,
      starts_at: tomorrow.in_time_zone.change(hour: 9)
    )
    allow(SupplierCalendarReminderNotification).to receive(:with)
      .and_raise(StandardError, 'Delivery failure')

    expect { described_class.perform_now(Date.current) }
      .to raise_error(StandardError, /Delivery failure/)
    expect(SupplierEventDelivery.count).to eq(0)
  end

  it 'skips inactive suppliers and completed individual events' do
    supplier.supplier_events.create!(
      title: 'Finished delivery', kind: 'delivery', status: 'completed', branch:,
      starts_at: tomorrow.in_time_zone.change(hour: 9)
    )
    expect { described_class.perform_now(Date.current) }
      .not_to change(SupplierEventDelivery, :count)

    supplier.supplier_events.create!(
      title: 'Pending delivery', kind: 'delivery', status: 'scheduled', branch:,
      starts_at: tomorrow.in_time_zone.change(hour: 10)
    )
    supplier.update!(status: 'inactive')

    expect { described_class.perform_now(Date.current) }
      .not_to change(SupplierEventDelivery, :count)
  end

  it 'does not send reminders for cancelled events' do
    supplier.supplier_events.create!(
      title: 'Cancelled visit', kind: 'visit', status: 'cancelled', branch:,
      starts_at: tomorrow.in_time_zone.change(hour: 9)
    )

    expect { described_class.perform_now(Date.current) }
      .not_to change(SupplierEventDelivery, :count)
  end

  it 'respects an exception suspending a weekly visit' do
    schedule = supplier.supplier_schedules.create!(
      branch:, kind: 'visit', weekday: tomorrow.wday,
      starts_at: '09:00', ends_at: '11:00'
    )
    supplier.supplier_schedule_exceptions.create!(
      branch:, supplier_schedule: schedule, reason: 'suspension', starts_on: tomorrow
    )

    expect { described_class.perform_now(Date.current) }
      .not_to change(SupplierEventDelivery, :count)
  end
end

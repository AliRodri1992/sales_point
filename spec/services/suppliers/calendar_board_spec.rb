# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::CalendarBoard do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:date) { Date.iso8601('2026-10-23') }

  it 'shows weekly schedules without suspensions and includes dated events separately' do
    schedule = SupplierSchedule.create!(supplier:, branch:, kind: 'visit', weekday: date.wday,
                                        starts_at: '09:00', ends_at: '11:00')
    supplier.supplier_events.create!(title: 'Special visit', branch:, kind: 'visit',
                                     starts_at: Time.zone.local(2026, 10, 23, 12))
    supplier.supplier_schedule_exceptions.create!(
      branch:, supplier_schedule: schedule, reason: 'suspension', starts_on: date
    )

    board = described_class.new(supplier:, month: '2026-10')
    expect(board.items_on(date).pluck(:type)).to eq([:event])
    expect(board.exception_count).to eq(1)
  end

  it 'filters by branch, kind and dates and ignores archived events' do
    supplier.supplier_events.create!(title: 'Visible delivery', branch:, kind: 'delivery',
                                     starts_at: Time.zone.local(2026, 10, 23, 12))
    supplier.supplier_events.create!(title: 'Deleted event', branch:, kind: 'delivery',
                                     starts_at: Time.zone.local(2026, 10, 23, 13),
                                     deleted_at: Time.current)
    supplier.supplier_events.create!(title: 'Other kind', branch:, kind: 'visit',
                                     starts_at: Time.zone.local(2026, 10, 23, 14))

    board = described_class.new(supplier:, month: '2026-10', branch_id: branch.id, kind: 'delivery')
    expect(board.items_on(date).pluck(:title)).to eq(['Visible delivery'])
    expect(board.next_navigation(1)[:calendar_month]).to eq('2026-11')
    expect(board.weeks.flatten).to include(date)
    expect(board.weeks.map(&:size).uniq).to eq([7])
  end

  it 'selects dates in the visible range and retains calendar filters in day navigation' do
    board = described_class.new(supplier:, month: '2026-10', selected_day: '2026-10-23',
                                kind: 'visit', branch_id: branch.id)
    expect(board.selected_date).to eq(date)
    expect(board.day_navigation(date)).to include(
      calendar_selected_day: '2026-10-23', calendar_branch: branch.id, calendar_kind: 'visit'
    )
    expect(board.selected_items).to be_empty

    board = described_class.new(supplier:, month: '2026-11', selected_day: '2026-10-23')
    expect(board.selected_date).to eq(Date.iso8601('2026-11-01'))
  end

  it 'keeps the month synchronized with week navigation across a month boundary' do
    board = described_class.new(supplier:, month: '2026-10', view: 'week', day: '2026-11-03')

    expect(board.month).to eq(Date.iso8601('2026-11-01'))
    expect(board.weeks.map(&:size)).to eq([7])
    expect(board.next_navigation(-1)[:calendar_day]).to eq('2026-10-27')
  end

  it 'handles invalid calendar dates without an exception' do
    board = described_class.new(supplier:, month: 'invalid', view: 'unknown', day: 'not-a-date')
    expect(board.view).to eq('month')
    expect(board.month).to eq(Date.current.beginning_of_month)
  end
end

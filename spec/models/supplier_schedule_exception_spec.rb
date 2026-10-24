# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierScheduleException, type: :model do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:, name: 'Receiving dock') }
  let(:schedule) do
    supplier.supplier_schedules.create!(
      branch:, kind: 'visit', weekday: Date.current.wday, starts_at: '09:00', ends_at: '10:00'
    )
  end

  it 'rejects exceptions for a different branch than their recurring schedule' do
    other_branch = create(:branch, organization:, name: 'Central depot')
    exception = described_class.new(
      supplier:, branch: other_branch, supplier_schedule: schedule,
      reason: 'suspension', starts_on: Date.current
    )
    expect(exception).not_to be_valid
    expect(exception.errors[:supplier_schedule]).to be_present
  end

  it 'allows an exception scoped to its matching supplier and branch' do
    exception = described_class.new(
      supplier:, branch:, supplier_schedule: schedule,
      reason: 'suspension', starts_on: Date.current
    )
    expect(exception).to be_valid
  end

  it 'rejects an exception extending beyond one year' do
    record = described_class.new(
      supplier:, reason: 'holiday',
      starts_on: Date.new(2026, 10, 1), ends_on: Date.new(2027, 11, 1)
    )

    expect(record).not_to be_valid
    expect(record.errors[:ends_on]).to be_present
  end

  it 'rejects exceptions scoped to another organizations branch' do
    other_branch = create(:branch, organization: create(:organization))
    record = described_class.new(
      supplier:, branch: other_branch, reason: 'suspension', starts_on: Date.current
    )

    expect(record).not_to be_valid
    expect(record.errors[:branch]).to be_present
  end

  it 'rejects selecting another suppliers recurring schedule' do
    other_supplier = create(:supplier, organization:)
    other_schedule = other_supplier.supplier_schedules.create!(
      branch:, kind: 'visit', weekday: 2, starts_at: '09:00', ends_at: '10:00'
    )
    record = described_class.new(
      supplier:, supplier_schedule: other_schedule, reason: 'holiday', starts_on: Date.current
    )

    expect(record).not_to be_valid
    expect(record.errors[:supplier_schedule]).to be_present
  end
end

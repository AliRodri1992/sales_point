# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierScheduleException, type: :model do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:schedule) do
    supplier.supplier_schedules.create!(
      branch:, kind: 'visit', weekday: Date.current.wday, starts_at: '09:00', ends_at: '10:00'
    )
  end

  it 'rejects exceptions for a different branch than their recurring schedule' do
    other_branch = create(:branch, organization:)
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
end

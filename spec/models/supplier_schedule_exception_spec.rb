# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierScheduleException, type: :model do
  let(:supplier) { create(:supplier) }
  let(:branch) { create(:branch, organization: supplier.organization) }

  it 'blocks weekly visits during an exception period' do
    schedule = SupplierSchedule.create!(
      supplier:, branch:, kind: 'delivery', weekday: 1,
      starts_at: '09:00', ends_at: '10:00'
    )
    monday = Date.current + ((1 - Date.current.wday) % 7)
    expect(schedule.occurs_on?(monday)).to be(true)

    described_class.create!(supplier:, starts_on: monday, reason: 'holiday')
    expect(schedule.occurs_on?(monday)).to be(false)
    expect(schedule.occurs_on?(monday + 7.days)).to be(true)
  end

  it 'rejects exceptions with wrong branch ownership or reverse dates' do
    exception = described_class.new(
      supplier:, branch: create(:branch, organization: create(:organization)),
      starts_on: Date.current, ends_on: Date.yesterday, reason: 'suspension'
    )
    expect(exception).not_to be_valid
    expect(exception.errors.attribute_names).to include(:branch, :ends_on)
  end
end

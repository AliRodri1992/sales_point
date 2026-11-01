# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierSchedule do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }

  it 'excludes soft-deleted schedules from active listings' do
    schedule = described_class.create!(
      supplier:, branch:, kind: 'visit', weekday: 1, starts_at: '09:00'
    )
    schedule.update!(deleted_at: Time.current)

    expect(described_class.not_deleted).not_to include(schedule)
  end
end

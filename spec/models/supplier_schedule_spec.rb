# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierSchedule, type: :model do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization: organization) }
  let(:branch) { create(:branch, organization: organization) }

  it 'accepts a visit schedule for a branch in the same organization' do
    schedule = described_class.new(supplier: supplier, branch: branch, kind: 'visit',
                                   weekday: 1, starts_at: '09:00')
    expect(schedule).to be_valid
  end

  it 'rejects a branch from a different organization' do
    other_branch = create(:branch, organization: create(:organization))
    schedule = described_class.new(supplier: supplier, branch: other_branch, kind: 'delivery',
                                   weekday: 2, starts_at: '10:00')
    expect(schedule).not_to be_valid
    expect(schedule.errors[:branch]).to be_present
  end

  it 'rejects an end time before the start time' do
    schedule = described_class.new(supplier: supplier, branch: branch, kind: 'visit',
                                   weekday: 1, starts_at: '14:00', ends_at: '12:00')
    expect(schedule).not_to be_valid
    expect(schedule.errors[:ends_at]).to be_present
  end

  it 'rejects an invalid weekday' do
    schedule = described_class.new(supplier: supplier, branch: branch, kind: 'order',
                                   weekday: 7, starts_at: '09:00')
    expect(schedule).not_to be_valid
  end
  it 'prevents overlapping windows for the same supplier, branch and event' do
    supplier = create(:supplier)
    branch = create(:branch, organization: supplier.organization)
    described_class.create!(
      supplier:, branch:, kind: 'delivery', weekday: 1,
      starts_at: '09:00', ends_at: '11:00'
    )
    conflicting = described_class.new(
      supplier:, branch:, kind: 'delivery', weekday: 1,
      starts_at: '10:00', ends_at: '12:00'
    )
    expect(conflicting).not_to be_valid
    expect(conflicting.errors.attribute_names).to include(:starts_at)
  end

  it 'enforces the database exclusion constraint even when Rails validations are bypassed' do
    described_class.create!(
      supplier:, branch:, kind: 'delivery', weekday: 1,
      starts_at: '09:00', ends_at: '11:00'
    )
    conflicting = described_class.new(
      supplier:, branch:, kind: 'delivery', weekday: 1,
      starts_at: '10:00', ends_at: '12:00'
    )

    expect do
      conflicting.save!(validate: false)
    end.to raise_error(ActiveRecord::StatementInvalid) { |error|
      expect(error.cause).to be_a(PG::ExclusionViolation)
    }
  end
end

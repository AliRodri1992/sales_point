# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierEvent, type: :model do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }

  it 'rejects creating new activities for inactive suppliers' do
    supplier.update!(status: :inactive)
    event = described_class.new(supplier:, branch:, kind: 'visit', title: 'Follow-up',
                                starts_at: Time.zone.now)
    expect(event).not_to be_valid
    expect(event.errors[:supplier]).to be_present
  end

  it 'allows updating an existing historical event after supplier deactivation' do
    event = described_class.create!(supplier:, branch:, kind: 'visit', title: 'Follow-up',
                                    starts_at: Time.zone.now)
    supplier.update!(status: :inactive)
    expect(event.update(title: 'Historical follow-up')).to be(true)
  end

  it 'falls back to the current timezone when no organization timezone exists' do
    event = described_class.create!(
      supplier:, branch:, kind: 'visit', title: 'No timezone',
      starts_at: Time.zone.parse('2026-10-25 00:15')
    )

    expect(event.occurs_on?(Date.new(2026, 10, 25))).to be(true)
    expect(event.occurs_on?(Date.new(2026, 10, 24))).to be(false)
  end

  it 'uses the organization timezone for events crossing a UTC date boundary' do
    create(:organization_setting, organization:, timezone: 'America/Mexico_City')
    event = described_class.create!(
      supplier:, branch:, kind: 'visit', title: 'Night delivery',
      starts_at: Time.utc(2026, 10, 25, 2, 0),
      ends_at: Time.utc(2026, 10, 25, 3, 0)
    )

    expect(event.occurs_on?(Date.new(2026, 10, 24))).to be(true)
    expect(event.occurs_on?(Date.new(2026, 10, 25))).to be(false)
  end

  it 'rejects an end time earlier than the start of an event' do
    event = described_class.new(
      supplier:, branch:, kind: 'visit', title: 'Reverse window',
      starts_at: Time.utc(2026, 10, 25, 14), ends_at: Time.utc(2026, 10, 25, 13)
    )

    expect(event).not_to be_valid
    expect(event.errors[:ends_at]).to be_present
  end

  it 'requires an end time for all-day activities' do
    event = described_class.new(
      supplier:, branch:, kind: 'visit', title: 'Full-day visit',
      starts_at: Time.utc(2026, 10, 25), all_day: true
    )

    expect(event).not_to be_valid
    expect(event.errors[:ends_at]).to be_present
  end

  it 'rejects assigning an activity to a different organizations branch' do
    foreign_branch = create(:branch, organization: create(:organization))
    event = described_class.new(
      supplier:, branch: foreign_branch, kind: 'visit', title: 'Mismatched branch',
      starts_at: Time.utc(2026, 10, 25)
    )

    expect(event).not_to be_valid
    expect(event.errors[:branch]).to be_present
  end

  it 'treats an event without an end time as a single local-day occurrence' do
    event = described_class.create!(
      supplier:, branch:, kind: 'visit', title: 'Single visit',
      starts_at: Time.utc(2026, 10, 25, 12)
    )

    expect(event.occurs_on?(Date.new(2026, 10, 25))).to be(true)
    expect(event.occurs_on?(Date.new(2026, 10, 26))).to be(false)
  end

  it 'treats an all-day event ending at midnight as exclusive of the following day' do
    event = described_class.create!(
      supplier:, branch:, kind: 'visit', title: 'Full-day activity', all_day: true,
      starts_at: Time.zone.local(2026, 10, 25), ends_at: Time.zone.local(2026, 10, 26)
    )

    expect(event.occurs_on?(Date.new(2026, 10, 25))).to be(true)
    expect(event.occurs_on?(Date.new(2026, 10, 26))).to be(false)
  end

  it 'rejects creating new events for an archived supplier' do
    supplier.update!(deleted_at: Time.current)
    event = described_class.new(
      supplier:, branch:, title: 'Archived supplier', kind: 'visit', starts_at: Time.current
    )

    expect(event).not_to be_valid
    expect(event.errors[:supplier]).to be_present
  end
end

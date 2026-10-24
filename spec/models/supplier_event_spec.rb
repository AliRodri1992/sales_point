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
end

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

  it 'rejects an invalid weekday' do
    schedule = described_class.new(supplier: supplier, branch: branch, kind: 'order',
                                   weekday: 7, starts_at: '09:00')
    expect(schedule).not_to be_valid
  end
end

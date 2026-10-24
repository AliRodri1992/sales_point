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
end

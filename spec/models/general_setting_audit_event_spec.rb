# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeneralSettingAuditEvent, type: :model do
  it 'keeps audit records immutable' do
    organization = create(:organization)
    actor = create(:user)
    event = described_class.create!(organization:, actor:, previous_page_size: 10, new_page_size: 25)

    expect(event.update(new_page_size: 50)).to be(false)
    expect(event.destroy).to be(false)
    expect(event.reload.new_page_size).to eq(25)
  end

  it 'rejects unsupported page sizes' do
    event = described_class.new(organization: create(:organization), actor: create(:user),
                                previous_page_size: 10, new_page_size: 999)
    expect(event).not_to be_valid
  end
end

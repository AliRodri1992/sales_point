# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::TestRecipient do
  let(:actor) { build_stubbed(:user, email: 'staff@example.com') }

  it 'requires a properly formatted recipient and rejects blank values' do
    candidate = described_class.new(email: '', actor:)
    expect(candidate).not_to be_valid
    expect(candidate.errors[:email]).to be_present
    candidate.email = 'invalid'
    expect(candidate).not_to be_valid
  end

  it 'allows sending a test only to the actor for ordinary administrators' do
    allow(actor).to receive(:role?).with('super_admin').and_return(false)
    expect(described_class.new(email: ' STAFF@example.com ', actor:).valid?).to be(true)
    other = described_class.new(email: 'someone@example.com', actor:)
    expect(other).not_to be_valid
    expect(other.errors[:email]).to be_present
  end
end

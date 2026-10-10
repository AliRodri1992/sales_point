# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingPolicy, type: :policy do
  subject(:policy) { described_class.new(user, :onboarding) }

  let(:user) { instance_double(User) }

  before do
    allow(user).to receive(:admin?).and_return(true)
    allow(user).to receive_message_chain(:organizations, :active_records, :exists?).and_return(true)
  end

  it 'permits administrators with an active organization' do
    expect(policy.show?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.reset?).to be(true)
  end

  context 'when the user is not an administrator' do
    before { allow(user).to receive(:admin?).and_return(false) }

    it 'denies all onboarding actions' do
      expect(policy.show?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.reset?).to be(false)
    end
  end

  context 'when no user is authenticated' do
    let(:user) { nil }

    it 'denies all onboarding actions without calling user methods' do
      expect(policy.show?).to be_falsey
      expect(policy.update?).to be_falsey
      expect(policy.reset?).to be_falsey
    end
  end

  context 'when the organization is inactive' do
    before do
      allow(user).to receive_message_chain(:organizations, :active_records, :exists?).and_return(false)
    end

    it 'denies all onboarding actions' do
      expect(policy.show?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.reset?).to be(false)
    end
  end
end

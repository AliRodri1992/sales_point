# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingPolicy, type: :policy do
  subject(:policy) { described_class.new(user, :onboarding) }

  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let!(:membership) { create(:organization_membership, organization:, user:) }

  before do
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator')) if user
  end

  it 'permits administrators with an active organization membership' do
    expect(policy.show?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.reset?).to be(true)
  end

  context 'when the user is not an administrator' do
    before { user.user_roles.destroy_all }

    it 'denies all onboarding actions' do
      expect(policy.show?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.reset?).to be(false)
    end
  end

  context 'when no user is authenticated' do
    let(:user) { nil }
    let!(:membership) { nil }

    it 'denies all onboarding actions without accessing memberships' do
      expect(policy.show?).to be_falsey
      expect(policy.update?).to be_falsey
      expect(policy.reset?).to be_falsey
    end
  end

  context 'when the organization membership is inactive' do
    before { membership.update!(status: :inactive) }

    it 'denies all onboarding actions' do
      expect(policy.show?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.reset?).to be(false)
    end
  end

  context 'when the organization is archived' do
    before { organization.update!(deleted_at: Time.current) }

    it 'denies all onboarding actions' do
      expect(policy.show?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.reset?).to be(false)
    end
  end
end

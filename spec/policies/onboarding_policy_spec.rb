# frozen_string_literal: true

RSpec.describe OnboardingPolicy do
  subject(:policy) { described_class.new(user, :onboarding) }

  let(:user) { create(:user) }

  context 'when the user is an administrator with an organization' do
    before do
      role = create(:system_role, :system, code: 'administrator')
      create(:user_role, user:, system_role: role)
      create(:organization_membership, user:)
    end

    it 'permits access' do
      expect(policy.show?).to be(true)
    end
  end

  it 'denies access without administrator role' do
    expect(policy.show?).to be(false)
  end
end

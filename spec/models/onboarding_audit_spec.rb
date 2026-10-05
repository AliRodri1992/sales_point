# frozen_string_literal: true

RSpec.describe OnboardingAudit, type: :model do
  subject(:audit) { build(:onboarding_audit) }

  it { is_expected.to validate_presence_of(:action) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:user) }

  it 'accepts supported onboarding steps' do
    audit.step = 5

    expect(audit).to be_valid
  end

  it 'rejects an invalid onboarding step' do
    audit.step = 6

    expect(audit).not_to be_valid
  end
end

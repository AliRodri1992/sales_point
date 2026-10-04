# frozen_string_literal: true

RSpec.describe Onboarding::Auditor do
  let(:organization) { instance_double(Organization) }
  let(:user) { instance_double(User) }

  it 'creates an audit entry with the onboarding action' do
    audit = instance_double(OnboardingAudit)
    expect(OnboardingAudit).to receive(:create!).with(
      organization: organization,
      user: user,
      action: 'step_updated',
      step: 3,
      section: 'terminals',
      metadata: { 'source' => 'onboarding' }
    ).and_return(audit)

    expect(
      described_class.call(
        organization: organization,
        user: user,
        action: 'step_updated',
        step: 3,
        section: 'terminals',
        metadata: { 'source' => 'onboarding' }
      )
    ).to eq(audit)
  end
end

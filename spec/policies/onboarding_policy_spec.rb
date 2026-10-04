# frozen_string_literal: true

RSpec.describe OnboardingPolicy, type: :policy do
  subject(:policy) { described_class.new(user, :onboarding) }

  let(:user) { instance_double(User) }

  before do
    allow(user).to receive(:admin?).and_return(true)
    allow(user).to receive_message_chain(:organizations, :active_records, :exists?).and_return(true)
  end

  it { is_expected.to permit_action(:show) }
  it { is_expected.to permit_action(:update) }
  it { is_expected.to permit_action(:reset) }

  context 'when the user is not an administrator' do
    before { allow(user).to receive(:admin?).and_return(false) }

    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:reset) }
  end
end

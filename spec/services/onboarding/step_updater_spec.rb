# frozen_string_literal: true

RSpec.describe Onboarding::StepUpdater do
  let(:organization) { instance_double(Organization, onboarding_current_step: 3) }
  let(:user) { instance_double(User) }
  let(:terminal_one) { instance_double(Terminal) }
  let(:terminal_two) { instance_double(Terminal) }
  let(:terminals) { [terminal_one, terminal_two] }

  let(:params) do
    ActionController::Parameters.new(
      terminal_names: { '0' => 'Caja Principal', '1' => 'Caja Secundaria' }
    )
  end

  before do
    allow(ApplicationRecord).to receive(:transaction).and_yield
    allow(Onboarding::ProgressSynchronizer).to receive(:call)
    allow(Onboarding::Auditor).to receive(:call)
    allow(Onboarding::StateCalculator).to receive(:new).and_return(
      instance_double(Onboarding::StateCalculator, call: {})
    )
    allow(terminal_one).to receive(:assign_attributes)
    allow(terminal_two).to receive(:assign_attributes)
    allow(terminal_one).to receive(:save!)
    allow(terminal_two).to receive(:save!)
    allow(organization).to receive(:update!)
  end

  it 'updates existing cash register names without creating new terminals' do
    expect(Terminal).not_to receive(:create!)
    expect(terminal_one).to receive(:assign_attributes).with(name: 'Caja Principal')
    expect(terminal_two).to receive(:assign_attributes).with(name: 'Caja Secundaria')
    expect(terminal_one).to receive(:save!).with(context: :onboardingstep3)
    expect(terminal_two).to receive(:save!).with(context: :onboardingstep3)

    expect(
      described_class.call(
        organization: organization,
        step: 3,
        params: params,
        user: user,
        terminals:
      )
    ).to be(true)
  end

  it 'does not complete onboarding when a section is incomplete' do
    allow(Onboarding::ProgressCalculator).to receive(:call).with(organization).and_return(
      sections: [{ key: :payments, percentage: 0, status: 'not_started' }]
    )
    expect(organization).not_to receive(:complete_onboarding!)

    expect(
      described_class.call(
        organization: organization,
        step: 5,
        params: ActionController::Parameters.new,
        user: user
      )
    ).to be(false)
  end
end

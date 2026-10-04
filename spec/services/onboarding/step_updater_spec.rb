# frozen_string_literal: true

RSpec.describe Onboarding::StepUpdater do
  let(:organization) { instance_double(Organization, onboarding_current_step: 3) }
  let(:user) { instance_double(User) }
  let(:terminal_one) { instance_double(Terminal) }
  let(:terminal_two) { instance_double(Terminal) }
  let(:terminals) { [terminal_one, terminal_two] }
  let(:branch) { instance_double(Branch) }
  let(:params) { ActionController::Parameters.new(terminal_names: { '0' => 'Caja Principal', '1' => 'Caja Secundaria' }) }

  before do
    allow(ApplicationRecord).to receive(:transaction).and_yield
    allow(Onboarding::ProgressSynchronizer).to receive(:call)
    allow(Onboarding::Auditor).to receive(:call)
    allow(organization).to receive_message_chain(:branches, :not_deleted, :where, :first).and_return(branch)
    allow(terminal_one).to receive(:update!)
    allow(terminal_two).to receive(:update!)
    allow(organization).to receive(:update!)
  end

  it 'updates existing cash register names without creating new terminals' do
    expect(Terminal).not_to receive(:create!)
    expect(terminal_one).to receive(:update!).with(name: 'Caja Principal')
    expect(terminal_two).to receive(:update!).with(name: 'Caja Secundaria')

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

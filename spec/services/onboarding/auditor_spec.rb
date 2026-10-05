# frozen_string_literal: true

RSpec.describe Onboarding::Auditor, type: :service do
  it 'records an onboarding action with its metadata' do
    organization = create(:organization)
    user = create(:user)

    audit = described_class.call(
      organization:,
      user:,
      action: 'step_updated',
      step: 2,
      section: 'branches',
      metadata: { 'changes' => { 'name' => 'Sucursal Centro' } }
    )

    expect(audit).to be_persisted
    expect(audit).to have_attributes(action: 'step_updated', step: 2, section: 'branches')
    expect(audit.metadata).to include('changes')
  end
end

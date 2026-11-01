# frozen_string_literal: true

RSpec.describe Onboarding::Requirement do
  let(:organization) { instance_double(Organization) }

  it 'reports a completed section' do
    allow(Onboarding::ProgressCalculator).to receive(:call).with(organization).and_return(
      sections: [{ key: :payments, percentage: 100, status: 'completed' }]
    )

    result = described_class.call(organization:, section: :payments)

    expect(result).to include(complete: true, section: :payments, percentage: 100)
  end

  it 'reports an incomplete section' do
    allow(Onboarding::ProgressCalculator).to receive(:call).with(organization).and_return(
      sections: [{ key: :payments, percentage: 0, status: 'not_started' }]
    )

    result = described_class.call(organization:, section: :payments)

    expect(result).to include(complete: false, section: :payments, percentage: 0)
  end
end

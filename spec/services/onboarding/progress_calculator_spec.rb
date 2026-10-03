# frozen_string_literal: true

RSpec.describe Onboarding::ProgressCalculator, type: :service do
  it 'reports progressive completion without blocking access' do
    organization = create(:organization, :with_settings)
    create(:employee, organization:)

    progress = described_class.call(organization)

    expect(progress[:sections]).to include(
      include(key: :company, status: 'completed'),
      include(key: :fiscal, status: 'completed'),
      include(key: :branches, status: 'not_started'),
      include(key: :terminals, status: 'not_started'),
      include(key: :team, status: 'completed')
    )
    expect(progress[:percentage]).to eq(50)
  end
end
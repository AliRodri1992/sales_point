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
    expect(progress[:percentage]).to eq(66)
  end

  it 'reports partial configuration as in progress' do
    organization = create(:organization)
    create(:branch, organization:, without_address: true)

    progress = described_class.call(organization)

    expect(progress[:sections]).to include(
      include(key: :company, status: 'in_progress'),
      include(key: :fiscal, status: 'completed'),
      include(key: :branches, status: 'in_progress'),
      include(key: :terminals, status: 'not_started'),
      include(key: :payments, status: 'not_started'),
      include(key: :team, status: 'not_started')
    )
  end

  it 'reports fully configured operational sections as completed' do
    organization = create(:organization, :with_settings)
    create(:branch, organization:)
    create(:terminal, branch: organization.branches.first)
    create(:employee, organization:)
    organization.organization_settings.first.update!(payment_method: :card)

    progress = described_class.call(organization)

    expect(progress[:sections]).to all(include(:key, :percentage, :status))
    expect(progress[:sections]).to all(include(status: 'completed'))
    expect(progress[:percentage]).to eq(100)
  end
end

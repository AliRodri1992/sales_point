# frozen_string_literal: true

RSpec.describe Onboarding::ProgressSynchronizer, type: :service do
  it 'persists calculated section progress' do
    organization = create(:organization, :with_settings)

    result = described_class.call(organization:)

    expect(result).to include(:sections, :percentage)
    expect(organization.reload.onboarding_sections).to be_present
    expect(organization.onboarding_sections.keys).to include('company', 'fiscal', 'branches')
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Onboarding usability regressions', type: :service do
  it 'allows a valid Hong Kong address to reach complete progress' do
    organization = create(:organization, :with_settings)
    branch = create(:branch, organization:, without_address: true)
    country = create(:country, iso_alpha2: 'HK', iso_alpha3: 'HKG', iso_numeric: '344')
    branch.create_address!(street: 'Queens Road', city: 'Hong Kong', country:)
    create(:employee, organization:)
    create(:terminal, branch:)
    progress = Onboarding::ProgressCalculator.call(organization.reload)
    expect(progress[:percentage]).to eq(100)
  end

  it 'does not count a register in an inactive branch as an operational register' do
    organization = create(:organization)
    branch = create(:branch, organization:, status: false)
    create(:terminal, branch:)
    progress = Onboarding::ProgressCalculator.call(organization)
    expect(progress[:sections].find { |section| section[:key] == :terminals }[:percentage]).to eq(0)
  end

  it 'records the section that the submitted step actually edits' do
    { 1 => :company, 2 => :branches, 3 => :terminals, 4 => :payments }.each do |step, section|
      updater = Onboarding::StepUpdater.new(double, step, {}, double)
      expect(updater.send(:section_key)).to eq(section)
    end
  end
end

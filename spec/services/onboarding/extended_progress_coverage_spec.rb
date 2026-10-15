# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Extended organization onboarding progress branches', type: :service do
  let(:organization) { double('Organization') }
  let(:calculator) { Onboarding::ProgressCalculator.new(organization) }

  def stub_branches(branch)
    relation = double
    allow(relation).to receive(:not_deleted).and_return(relation)
    allow(relation).to receive(:where).and_return(relation)
    allow(relation).to receive(:first).and_return(branch)
    allow(organization).to receive(:branches).and_return(relation)
    relation
  end

  it 'sets branch progress to zero when no active branch exists' do
    stub_branches(nil)
    expect(calculator.send(:branch_section)).to include(percentage: 0)
  end

  it 'treats a branch without a complete address as partially configured' do
    stub_branches(double(name: 'Main', address: nil))
    expect(calculator.send(:branch_section)).to include(percentage: 50)
  end

  it 'treats a branch with a complete address as fully configured' do
    address = double(street: 'Main', exterior_number: '1', neighborhood: 'North',
                     city: 'Mexico', state: 'Mexico', country: double, postal_code: '12345')
    stub_branches(double(name: 'Main', address:))
    expect(calculator.send(:branch_section)).to include(percentage: 100)
  end

  it 'reports missing company information' do
    allow(organization).to receive_messages(name: nil, business_sector: nil,
                                             organization_settings: double(first: nil))
    expect(calculator.send(:company_section)).to include(percentage: 0)
  end

  it 'reports complete company information when settings are configured' do
    settings = double(base_currency_id: 1, timezone: 'America/Mexico_City')
    allow(organization).to receive_messages(name: 'Company', business_sector: 'grocery',
                                             organization_settings: double(first: settings))
    expect(calculator.send(:company_section)).to include(percentage: 100)
  end

  it 'checks active terminal existence' do
    branches = double
    allow(branches).to receive(:joins).and_return(branches)
    allow(branches).to receive(:merge).and_return(branches)
    allow(branches).to receive(:exists?).and_return(false, true)
    allow(organization).to receive(:branches).and_return(branches)
    expect(calculator.send(:terminal_section)).to include(percentage: 0)
    expect(calculator.send(:terminal_section)).to include(percentage: 100)
  end
end

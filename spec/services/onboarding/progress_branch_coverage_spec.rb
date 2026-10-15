# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Onboarding progress calculation decisions', type: :service do
  let(:organization) { double('Organization') }
  let(:calculator) { Onboarding::ProgressCalculator.new(organization) }

  it 'calculates empty and partially completed field percentages' do
    expect(calculator.send(:percentage_for, [])).to eq(0)
    expect(calculator.send(:percentage_for, [nil, nil])).to eq(0)
    expect(calculator.send(:percentage_for, ['value', nil])).to eq(50)
    expect(calculator.send(:percentage_for, ['value'])).to eq(100)
  end

  it 'handles empty and weighted section aggregations' do
    expect(calculator.send(:overall_percentage, [])).to eq(0)
    sections = [{ percentage: 20 }, { percentage: 80 }]
    expect(calculator.send(:overall_percentage, sections)).to eq(50)
  end

  it 'classifies all three progress states' do
    expect(calculator.send(:status_for, 0)).to eq('not_started')
    expect(calculator.send(:status_for, 55)).to eq('in_progress')
    expect(calculator.send(:status_for, 100)).to eq('completed')
  end

  it 'respects an explicitly non-applicable section status' do
    result = calculator.send(:section, :migration, 0, status: 'not_applicable')
    expect(result).to include(status: 'not_applicable', percentage: 0)
  end

  it 'reports missing tax identification as incomplete' do
    allow(organization).to receive(:tax_id).and_return(nil)
    expect(calculator.send(:fiscal_section)).to include(percentage: 0)
    allow(organization).to receive(:tax_id).and_return('AAA010101AAA')
    expect(calculator.send(:fiscal_section)).to include(percentage: 100)
  end

  it 'marks migration not applicable when no migration exists' do
    allow(organization).to receive(:organization_migrations)
      .and_return(double(first: nil))
    result = calculator.send(:migration_section)
    expect(result).to include(status: 'not_applicable')
  end

  it 'calculates partial migration when one of two fields is missing' do
    migration = double(volume: 100, priority: nil)
    allow(organization).to receive(:organization_migrations)
      .and_return(double(first: migration))
    expect(calculator.send(:migration_section)).to include(percentage: 50)
  end

  it 'distinguishes configured and unconfigured teams' do
    employees = double(active: double(exists?: false))
    allow(organization).to receive(:employees).and_return(employees)
    expect(calculator.send(:team_section)).to include(percentage: 0)
    allow(employees).to receive(:active).and_return(double(exists?: true))
    expect(calculator.send(:team_section)).to include(percentage: 100)
  end

  it 'distinguishes configured and missing payment methods' do
    allow(organization).to receive(:organization_settings)
      .and_return(double(first: nil))
    expect(calculator.send(:payment_section)).to include(percentage: 0)

    calculator_with_settings = Onboarding::ProgressCalculator.new(organization)
    settings = double(payment_method: 'cash')
    allow(organization).to receive(:organization_settings)
      .and_return(double(first: settings))
    expect(calculator_with_settings.send(:payment_section)).to include(percentage: 100)
  end
end

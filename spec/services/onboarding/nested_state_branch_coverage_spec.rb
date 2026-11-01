# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Onboarding nested-state changes and completion validation', type: :service do
  let(:organization) { double('Organization') }
  let(:updater) { Onboarding::StepUpdater.new(organization, 5, {}, double) }

  it 'recognizes no changes when before and after data are equal' do
    before = { 'name' => 'Main', 'address' => { 'city' => 'Mexico' } }
    expect(updater.send(:diff_hash, before, before)).to eq({})
  end

  it 'extracts nested changes without reporting unchanged fields' do
    old_values = { 'name' => 'A', 'address' => { 'city' => 'Old', 'zip' => '12345' } }
    new_values = { 'name' => 'B', 'address' => { 'city' => 'New', 'zip' => '12345' } }
    result = updater.send(:diff_hash, old_values, new_values)
    expect(result.fetch('name')).to eq('from' => 'A', 'to' => 'B')
    expect(result.fetch('address').fetch('city')).to eq('from' => 'Old', 'to' => 'New')
    expect(result.fetch('address').keys).not_to include('zip')
  end

  it 'records replaced scalar values even when one side is a hash' do
    result = updater.send(:diff_hash, { 'value' => { 'nested' => 1 } }, { 'value' => 'new' })
    expect(result.fetch('value')).to include('to' => 'new')
  end

  it 'rejects completion when any applicable section is unfinished' do
    allow(Onboarding::ProgressCalculator).to receive(:call)
      .and_return(sections: [{ status: 'in_progress', percentage: 80 }])
    expect(updater.send(:complete_onboarding?)).to be(false)
  end

  it 'ignores non-applicable steps when completing onboarding' do
    allow(Onboarding::ProgressCalculator).to receive(:call)
      .and_return(sections: [{ status: 'not_applicable', percentage: 0 },
                             { status: 'completed', percentage: 100 }])
    allow(organization).to receive(:complete_onboarding!)
    expect(updater.send(:complete_onboarding?)).to be(true)
    expect(organization).to have_received(:complete_onboarding!)
  end

  it 'rejects invalid onboarding steps instead of performing changes' do
    invalid = Onboarding::StepUpdater.new(organization, 9, {}, double)
    expect(invalid.send(:execute_step)).to be(false)
  end

  it 'advances the current step without exceeding the fifth step' do
    current = Onboarding::StepUpdater.new(organization, 4, {}, double)
    allow(organization).to receive(:update!)
    current.send(:advance_step)
    expect(organization).to have_received(:update!).with(onboarding_current_step: 5)
  end
end

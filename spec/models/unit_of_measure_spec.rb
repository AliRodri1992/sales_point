# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UnitOfMeasure, type: :model do
  let(:organization) { create(:organization) }
  let(:sat) { create(:sat_unit_key, code: 'H87') }

  it 'requires the fiscal key and seven-field catalog rules' do
    unit = build(:unit_of_measure, organization:, sat_unit_key: sat, name: '', code: 'bad code',
                                   abbreviation: '', decimal_precision: 7)
    expect(unit).not_to be_valid
    expect(unit.errors.attribute_names).to include(:name, :code, :abbreviation, :decimal_precision)
  end

  it 'normalizes codes and prevents duplicates within an organization' do
    create(:unit_of_measure, organization:, sat_unit_key: sat, code: 'PZA')
    duplicate = build(:unit_of_measure, organization:, sat_unit_key: sat, code: ' pza ')
    expect(duplicate).not_to be_valid
    expect(duplicate.code).to eq('PZA')
  end

  it 'allows identical codes in distinct organizations and after soft deletion' do
    original = create(:unit_of_measure, organization:, sat_unit_key: sat, code: 'PZA')
    expect(build(:unit_of_measure, organization: create(:organization), sat_unit_key: sat,
                                   code: 'PZA')).to be_valid
    original.update!(deleted_at: Time.current)
    expect(build(:unit_of_measure, organization:, sat_unit_key: sat, code: 'PZA')).to be_valid
  end

  it 'rejects expired SAT unit keys' do
    expired = create(:sat_unit_key, code: 'KGM', valid_to: 1.day.ago)
    expect(build(:unit_of_measure, organization:, sat_unit_key: expired)).not_to be_valid
  end

  it 'allows fractions only with nonzero decimal precision' do
    expect(build(:unit_of_measure, decimal_precision: 0)).not_to be_allows_fractions
    expect(build(:unit_of_measure, decimal_precision: 3)).to be_allows_fractions
  end

  it 'allows inactivation without changing the assigned fiscal key or deletion timestamp' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat)
    sat.update!(valid_to: Date.yesterday)

    expect(unit.update(status: 'inactive')).to be(true)
    expect(unit.reload).to be_inactive
    expect(unit.deleted_at).to be_nil
    expect(unit.sat_unit_key_id).to eq(sat.id)
    expect(unit).not_to be_sat_unit_key_current
  end

  it 'blocks reactivation with expired SAT and preserves the inactive record' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat, status: 'inactive')
    sat.update!(valid_to: Date.yesterday)

    expect(unit.update(status: 'active')).to be(false)
    expect(unit.errors.attribute_names).to include(:sat_unit_key)
    expect(unit.reload).to be_inactive
    expect(unit.deleted_at).to be_nil
  end

  it 'allows reactivation with a current SAT key' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat, status: 'inactive')

    expect(unit.update(status: 'active')).to be(true)
    expect(unit.reload).to be_active
    expect(unit).to be_sat_unit_key_current
  end

  it 'retains historical SAT association after soft-deleting the official key' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat, status: 'inactive')
    sat.update!(deleted_at: Time.current)

    expect(unit.reload.sat_unit_key.code).to eq('H87')
    expect(unit).not_to be_sat_unit_key_current
    expect(unit.update(status: 'active')).to be(false)
    expect(unit.errors.attribute_names).to include(:sat_unit_key)
  end

  it 'allows editing an inactive unit whose SAT key is expired without reactivating it' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat, status: 'inactive')
    sat.update!(valid_to: Date.yesterday)

    expect(unit.update(name: 'Archived unit label')).to be(true)
    expect(unit.reload.name).to eq('Archived unit label')
  end
end

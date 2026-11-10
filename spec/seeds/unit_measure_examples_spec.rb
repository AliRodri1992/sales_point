# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/seed_console')
require Rails.root.join('db/seeds/sat_catalogs')
require Rails.root.join('db/seeds/unit_measure_examples')

RSpec.describe UnitMeasureExamples, type: :model do
  let(:organization) { create(:organization) }

  before { SatCatalogSeeds.seed_units }

  it 'loads frequent official SAT keys and 28 tenant units with valid mappings and precision' do
    expect(SatUnitKey.current.where(code: SatCatalogExtraData::UNITS.keys).count)
      .to eq(SatCatalogExtraData::UNITS.size)

    expect { described_class.seed!(organization:) }.not_to change(Product, :count)

    expect(organization.units_of_measure.count).to eq(described_class::DATA.size)
    expect(organization.units_of_measure.find_by!(code: 'PZA').sat_unit_key.code).to eq('H87')
    kilo = organization.units_of_measure.find_by!(code: 'KILO')
    expect(kilo.sat_unit_key.code).to eq('KGM')
    expect(kilo.decimal_precision).to eq(3)
    expect(kilo).to be_allows_fractions
    expect(organization.units_of_measure.find_by!(code: 'CAJA').decimal_precision).to eq(0)
  end

  it 'does not duplicate records or overwrite manual edits for either catalog on repeat' do
    described_class.seed!(organization:)
    first_ids = organization.units_of_measure.order(:id).pluck(:id)
    sat = SatUnitKey.find_by!(code: 'H87')
    sat.update!(description: 'Descripción fiscal modificada')
    unit = organization.units_of_measure.find_by!(code: 'PZA')
    unit.update!(name: 'Pieza personalizada', abbreviation: 'ud', status: :inactive)

    SatCatalogSeeds.seed_units
    described_class.seed!(organization:)

    expect(organization.units_of_measure.order(:id).pluck(:id)).to eq(first_ids)
    expect(unit.reload).to have_attributes(name: 'Pieza personalizada', abbreviation: 'ud', status: 'inactive')
    expect(sat.reload.description).to eq('Descripción fiscal modificada')
  end

  it 'preserves logically deleted units and does not seed into unrelated tenants' do
    other_organization = create(:organization)
    described_class.seed!(organization:)
    unit = organization.units_of_measure.find_by!(code: 'PZA')
    unit.update!(deleted_at: Time.current)

    described_class.seed!(organization:)

    expect(UnitOfMeasure.with_deleted.where(organization:, code: 'PZA').count).to eq(1)
    expect(organization.units_of_measure.where(code: 'PZA')).to be_empty
    expect(other_organization.units_of_measure).to be_empty
  end

  it 'skips unavailable SAT keys rather than reactivating retired official entries' do
    sat = SatUnitKey.find_by!(code: 'KGM')
    sat.update!(deleted_at: Time.current)

    described_class.seed!(organization:)

    expect(organization.units_of_measure.where(code: 'KILO')).to be_empty
    expect(organization.units_of_measure.where(code: 'PZA')).to exist
    expect(sat.reload.deleted_at).to be_present
  end
end

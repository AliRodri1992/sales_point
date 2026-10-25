# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SAT CFDI 4.0 application models', type: :model do
  it 'maps SatCfdiUse to cfdi_uses and supports validity and soft deletion' do
    model = SatCfdiUse
    expect(model.table_name).to eq('sat_cfdi_uses')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatVoucherType to voucher_types and supports validity and soft deletion' do
    model = SatVoucherType
    expect(model.table_name).to eq('sat_voucher_types')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatProductServiceKey to product_service_keys and supports validity and soft deletion' do
    model = SatProductServiceKey
    expect(model.table_name).to eq('sat_product_service_keys')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatFactorType to factor_types and supports validity and soft deletion' do
    model = SatFactorType
    expect(model.table_name).to eq('sat_factor_types')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatTaxObject to tax_objects and supports validity and soft deletion' do
    model = SatTaxObject
    expect(model.table_name).to eq('sat_tax_objects')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatPostalCode to postal_codes and supports validity and soft deletion' do
    model = SatPostalCode
    expect(model.table_name).to eq('sat_postal_codes')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatCountry to countries and supports validity and soft deletion' do
    model = SatCountry
    expect(model.table_name).to eq('sat_countries')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatExportType to export_types and supports validity and soft deletion' do
    model = SatExportType
    expect(model.table_name).to eq('sat_export_types')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatPeriodicity to periodicities and supports validity and soft deletion' do
    model = SatPeriodicity
    expect(model.table_name).to eq('sat_periodicities')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatRelationshipType to relationship_types and supports validity and soft deletion' do
    model = SatRelationshipType
    expect(model.table_name).to eq('sat_relationship_types')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatCustomsOffice to customs_offices and supports validity and soft deletion' do
    model = SatCustomsOffice
    expect(model.table_name).to eq('sat_customs_offices')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatCustomsPatent to customs_patents and supports validity and soft deletion' do
    model = SatCustomsPatent
    expect(model.table_name).to eq('sat_customs_patents')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatCustomsPedimentNumber to customs_pediment_numbers and supports validity and soft deletion' do
    model = SatCustomsPedimentNumber
    expect(model.table_name).to eq('sat_customs_pediment_numbers')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatTaxRate to tax_rates and supports validity and soft deletion' do
    model = SatTaxRate
    expect(model.table_name).to eq('sat_tax_rates')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatTaxCode to tax_codes and supports validity and soft deletion' do
    model = SatTaxCode
    expect(model.table_name).to eq('sat_tax_codes')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatNeighborhood to neighborhoods and supports validity and soft deletion' do
    model = SatNeighborhood
    expect(model.table_name).to eq('sat_neighborhoods')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatState to states and supports validity and soft deletion' do
    model = SatState
    expect(model.table_name).to eq('sat_states')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatLocality to localities and supports validity and soft deletion' do
    model = SatLocality
    expect(model.table_name).to eq('sat_localities')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'maps SatMunicipality to municipalities and supports validity and soft deletion' do
    model = SatMunicipality
    expect(model.table_name).to eq('sat_municipalities')
    expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to')
    expect(model.respond_to?(:with_deleted)).to be(true)
    expect(model.valid_on(Date.current).to_sql).to include('valid_from')
  end

  it 'connects the SAT country and state catalogs using their SAT codes' do
    expect(SatState.reflect_on_association(:country).foreign_key).to eq('country_code')
    expect(SatCountry.reflect_on_association(:states).foreign_key).to eq('country_code')
  end

  it 'connects tax rates to tax codes using SAT identifiers' do
    expect(SatTaxRate.reflect_on_association(:tax_code_catalog).foreign_key).to eq('tax_code')
  end
end

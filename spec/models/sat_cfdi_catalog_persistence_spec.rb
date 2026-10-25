# frozen_string_literal: true

require 'rails_helper'

# Persistence contracts without adding application models or importers.
RSpec.describe 'SAT CFDI 4.0 catalog persistence', type: :model do
  [
    ['sat_cfdi_uses', %w[code], { code: 'G03', description: 'Gastos en general' }],
    ['sat_voucher_types', %w[code], { code: 'I', description: 'Ingreso' }],
    ['sat_product_service_keys', %w[code], { code: '01010101', description: 'Sin clasificar' }],
    ['sat_factor_types', %w[code], { code: 'Tasa', description: 'Tasa' }],
    ['sat_tax_objects', %w[code], { code: '02', description: 'Sí objeto del impuesto' }],
    ['sat_postal_codes', %w[code], { code: '01000', description: 'Código postal' }],
    ['sat_countries', %w[code], { code: 'MEX', description: 'México' }],
    ['sat_export_types', %w[code], { code: '01', description: 'No aplica' }],
    ['sat_periodicities', %w[code], { code: '01', description: 'Diario' }],
    ['sat_relationship_types', %w[code], { code: '01', description: 'Relacionados' }],
    ['sat_customs_offices', %w[code], { code: '01', description: 'Aduana' }],
    ['sat_customs_patents', %w[code], { code: '1234', description: 'Patente' }],
    ['sat_customs_pediment_numbers', %w[code], { code: '24 01 1234 0000123', description: 'Pedimento' }],
    ['sat_tax_rates', %w[catalog_key],
     { catalog_key: '002/Tasa/transfer/0.16', description: 'IVA',,
       tax_code: '002', factor_type: 'Tasa', tax_type: 'transfer' }],
    ['sat_tax_codes', %w[code], { code: '002', description: 'IVA' }],
    ['sat_neighborhoods', %w[postal_code code],
     { code: '0001', description: 'Colonia', postal_code: '01000' }],
    ['sat_states', %w[country_code code],
     { code: 'AGU', description: 'Aguascalientes', country_code: 'MEX' }],
    ['sat_localities', %w[state_code code],
     { code: '0001', description: 'Localidad', state_code: 'AGU' }],
    ['sat_municipalities', %w[state_code code],
     { code: '0001', description: 'Municipio', state_code: 'AGU' }],
  ].each do |table, keys, attributes|
    describe table do
      let(:model) do
        Class.new(ApplicationRecord).tap { |klass| klass.table_name = table }
      end

      it 'provides validity dates and a Paranoia-compatible timestamp' do
        expect(model.column_names).to include('deleted_at', 'valid_from', 'valid_to', 'status')
        expect(model.columns_hash.fetch('deleted_at').type).to eq(:datetime)
      end

      it 'uses a partial unique index scoped to non-deleted entries' do
        indexes = ActiveRecord::Base.connection.indexes(table)
        index = indexes.find { |item| item.name == "idx_#{table}_active_key" }

        expect(index).to be_present
        expect(index.unique).to be(true)
        expect(index.columns).to eq(keys)
        expect(index.where).to include('deleted_at IS NULL')
      end

      it 'enforces chronological validity at the database level' do
        constraints = ActiveRecord::Base.connection.check_constraints(table)
        expect(constraints.map(&:expression).join(' ')).to include('valid_to >= valid_from')
      end

      it 'retains a soft-deleted row for historical CFDI lookups' do
        record = model.create!(attributes)

        expect { record.destroy! }.to change(model, :count).by(-1)
        expect(model.with_deleted.find(record.id).deleted_at).to be_present
      end

      it 'permits reusing a code after the previous row was soft-deleted' do
        record = model.create!(attributes)
        record.destroy!

        replacement = model.create!(attributes)

        expect(replacement).to be_persisted
        expect(model.with_deleted.find(record.id).deleted_at).to be_present
      end
    end
  end
end

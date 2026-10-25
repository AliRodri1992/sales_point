# frozen_string_literal: true

require 'rails_helper'

# Test schema persistence without implementing new application models.
RSpec.describe 'SAT CFDI 4.0 catalog persistence', type: :model do
  CATALOGS = {
    'sat_cfdi_uses' => { keys: %w[code], attrs: { code: "G03", description: "Gastos en general" } },
    'sat_voucher_types' => { keys: %w[code], attrs: { code: "I", description: "Ingreso" } },
    'sat_product_service_keys' => { keys: %w[code], attrs: { code: "01010101", description: "No existe en el catálogo" } },
    'sat_factor_types' => { keys: %w[code], attrs: { code: "Tasa", description: "Tasa" } },
    'sat_tax_objects' => { keys: %w[code], attrs: { code: "02", description: "Objeto de impuesto" } },
    'sat_postal_codes' => { keys: %w[code], attrs: { code: "01000", description: "Código postal de prueba" } },
    'sat_countries' => { keys: %w[code], attrs: { code: "MEX", description: "México" } },
    'sat_export_types' => { keys: %w[code], attrs: { code: "01", description: "No aplica" } },
    'sat_periodicities' => { keys: %w[code], attrs: { code: "01", description: "Diario" } },
    'sat_relationship_types' => { keys: %w[code], attrs: { code: "01", description: "Relación" } },
    'sat_customs_offices' => { keys: %w[code], attrs: { code: "01", description: "Aduana" } },
    'sat_customs_patents' => { keys: %w[code], attrs: { code: "1234", description: "Patente" } },
    'sat_customs_pediment_numbers' => { keys: %w[code], attrs: { code: "24 01 1234 0000123", description: "Pedimento" } },
    'sat_tax_rates' => { keys: %w[catalog_key], attrs: { catalog_key: "002/Tasa/transfer/0.16", description: "IVA tasa", tax_code: "002", factor_type: "Tasa", tax_type: "transfer" } },
    'sat_tax_codes' => { keys: %w[code], attrs: { code: "002", description: "IVA" } },
    'sat_neighborhoods' => { keys: %w[postal_code code], attrs: { code: "0001", description: "Colonia", postal_code: "01000" } },
    'sat_states' => { keys: %w[country_code code], attrs: { code: "AGU", description: "Aguascalientes", country_code: "MEX" } },
    'sat_localities' => { keys: %w[state_code code], attrs: { code: "0001", description: "Localidad", state_code: "AGU" } },
    'sat_municipalities' => { keys: %w[state_code code], attrs: { code: "0001", description: "Municipio", state_code: "AGU" } }
  }.freeze

  CATALOGS.each do |table, definition|
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
        expect(index.columns).to eq(definition.fetch(:keys))
        expect(index.where).to include('deleted_at IS NULL')
      end

      it 'rejects inverted validity dates at the database level' do
        constraints = ActiveRecord::Base.connection.check_constraints(table)
        expect(constraints.map(&:expression).join(' ')).to include('valid_to >= valid_from')
      end

      it 'retains historical entries after a soft delete' do
        record = model.create!(definition.fetch(:attrs))

        expect { record.destroy! }.to change(model, :count).by(-1)
        expect(model.with_deleted.find(record.id).deleted_at).to be_present
      end

      it 'allows a new active entry for a previously soft-deleted key' do
        old_record = model.create!(definition.fetch(:attrs))
        old_record.destroy!

        replacement = model.create!(definition.fetch(:attrs))

        expect(replacement).to be_persisted
        expect(model.with_deleted.find(old_record.id).deleted_at).to be_present
      end
    end
  end
end

# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatTaxRates < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_tax_rates do |t|
      # The SAT c_TasaOCuota catalog has a composite natural key, not a single code.
      t.string :catalog_key, limit: 160, null: false
      t.string :description, limit: 255, null: false
      t.string :tax_code, limit: 3, null: false
      t.string :factor_type, limit: 10, null: false
      t.string :tax_type, limit: 12, null: false
      t.decimal :minimum_rate, precision: 14, scale: 8
      t.decimal :maximum_rate, precision: 14, scale: 8
      t.boolean :fixed_rate, null: false, default: false
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_tax_rates, :catalog_key, unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_tax_rates_active_key'
    add_index :sat_tax_rates, :deleted_at
    add_index :sat_tax_rates, %i[valid_from valid_to], name: 'idx_sat_tax_rates_validity'
    add_index :sat_tax_rates, :tax_code, name: 'idx_sat_tax_rates_tax_code'
    add_index :sat_tax_rates, :factor_type, name: 'idx_sat_tax_rates_factor_type'
    add_index :sat_tax_rates, :tax_type, name: 'idx_sat_tax_rates_tax_type'

    add_check_constraint :sat_tax_rates,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_tax_rates_validity'
  end
end

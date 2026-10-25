# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatTaxCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_tax_codes do |t|
      # SAT c_Impuesto; separate from application-specific SatTax configurations.
      t.string :code, limit: 3, null: false
      t.string :description, limit: 255, null: false
      t.boolean :allows_withholding, null: false, default: false
      t.boolean :allows_transfer, null: false, default: false
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_tax_codes, :code, unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_tax_codes_active_key'
    add_index :sat_tax_codes, :deleted_at
    add_index :sat_tax_codes, %i[valid_from valid_to], name: 'idx_sat_tax_codes_validity'

    add_check_constraint :sat_tax_codes,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_tax_codes_validity'
    add_check_constraint :sat_tax_codes,
                         "code ~ '^[0-9]{3}",
                         name: 'chk_sat_tax_codes_code_format'
  end
end

# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatCfdiUses < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_cfdi_uses do |t|
      t.string :code, limit: 4, null: false
      t.string :description, limit: 255, null: false
      t.boolean :applies_to_individual, null: false, default: false
      t.boolean :applies_to_company, null: false, default: false
      t.text :fiscal_regime_codes, array: true, default: [], null: false
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_cfdi_uses, :code, unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_cfdi_uses_active_key'
    add_index :sat_cfdi_uses, :deleted_at
    add_index :sat_cfdi_uses, %i[valid_from valid_to], name: 'idx_sat_cfdi_uses_validity'

    add_check_constraint :sat_cfdi_uses,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_cfdi_uses_validity'
    add_check_constraint :sat_cfdi_uses,
                         "code ~ '^[A-Z0-9]{3,4}",
                         name: 'chk_sat_cfdi_uses_code_format'
  end
end

# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatPostalCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_postal_codes do |t|
      t.string :code, limit: 5, null: false
      t.string :description, limit: 255, null: false
      t.string :state_code, limit: 3
      t.string :municipality_code, limit: 5
      t.string :locality_code, limit: 5
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_postal_codes, :code, unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_postal_codes_active_key'
    add_index :sat_postal_codes, :deleted_at
    add_index :sat_postal_codes, %i[valid_from valid_to], name: 'idx_sat_postal_codes_validity'
    add_index :sat_postal_codes, :state_code, name: 'idx_sat_postal_codes_state_code'
    add_index :sat_postal_codes, :municipality_code, name: 'idx_sat_postal_codes_municipality_code'

    add_check_constraint :sat_postal_codes,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_postal_codes_validity'
    add_check_constraint :sat_postal_codes,
                         "code ~ '^[0-9]{5}$'",
                         name: 'chk_sat_postal_codes_code_format'
  end
end

# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatMunicipalities < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_municipalities do |t|
      t.string :code, limit: 5, null: false
      t.string :description, limit: 255, null: false
      t.string :state_code, limit: 3, null: false
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_municipalities, %i[state_code code], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_municipalities_active_key'
    add_index :sat_municipalities, :deleted_at
    add_index :sat_municipalities, %i[valid_from valid_to], name: 'idx_sat_municipalities_validity'
    add_index :sat_municipalities, :state_code, name: 'idx_sat_municipalities_state_code'

    add_check_constraint :sat_municipalities,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_municipalities_validity'
  end
end

# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatStates < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_states do |t|
      t.string :code, limit: 3, null: false
      t.string :description, limit: 255, null: false
      t.string :country_code, limit: 3, null: false
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_states, %i[country_code code], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_states_active_key'
    add_index :sat_states, :deleted_at
    add_index :sat_states, %i[valid_from valid_to], name: 'idx_sat_states_validity'
    add_index :sat_states, :country_code, name: 'idx_sat_states_country_code'

    add_check_constraint :sat_states,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_states_validity'
    add_check_constraint :sat_states,
                         "code ~ '^[A-Z0-9]{2,3}$'",
                         name: 'chk_sat_states_details'
  end
end

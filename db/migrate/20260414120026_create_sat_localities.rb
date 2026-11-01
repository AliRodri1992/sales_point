# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatLocalities < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_localities do |t|
      t.string :code, limit: 5, null: false
      t.string :description, limit: 255, null: false
      t.string :state_code, limit: 3, null: false
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_localities, %i[state_code code], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_localities_active_key'
    add_index :sat_localities, :deleted_at
    add_index :sat_localities, %i[valid_from valid_to], name: 'idx_sat_localities_validity'
    add_index :sat_localities, :state_code, name: 'idx_sat_localities_state_code'

    add_check_constraint :sat_localities,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_localities_validity'
    add_check_constraint :sat_localities,
                         "code ~ '^[0-9]{1,5}$'",
                         name: 'chk_sat_localities_details'
  end
end

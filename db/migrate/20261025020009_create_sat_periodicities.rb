# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatPeriodicities < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_periodicities do |t|
      t.string :code, limit: 2, null: false
      t.string :description, limit: 255, null: false
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_periodicities, :code, unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_periodicities_active_key'
    add_index :sat_periodicities, :deleted_at
    add_index :sat_periodicities, %i[valid_from valid_to], name: 'idx_sat_periodicities_validity'

    add_check_constraint :sat_periodicities,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_periodicities_validity'
    add_check_constraint :sat_periodicities,
                         "code ~ '^[0-9]{2}",
                         name: 'chk_sat_periodicities_code_format'
  end
end

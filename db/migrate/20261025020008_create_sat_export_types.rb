# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatExportTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_export_types do |t|
      t.string :code, limit: 2, null: false
      t.string :description, limit: 255, null: false
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_export_types, :code, unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_export_types_active_key'
    add_index :sat_export_types, :deleted_at
    add_index :sat_export_types, %i[valid_from valid_to], name: 'idx_sat_export_types_validity'

    add_check_constraint :sat_export_types,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_export_types_validity'
    add_check_constraint :sat_export_types,
                         "code ~ '^[0-9]{2}$'",
                         name: 'chk_sat_export_types_code_format'
  end
end

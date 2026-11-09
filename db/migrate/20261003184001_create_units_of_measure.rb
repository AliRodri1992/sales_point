# frozen_string_literal: true

class CreateUnitsOfMeasure < ActiveRecord::Migration[8.1]
  def change
    create_table :units_of_measure do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :sat_unit_key, null: false, foreign_key: true
      t.string :code, limit: 20, null: false
      t.string :name, limit: 100, null: false
      t.string :abbreviation, limit: 12, null: false
      t.string :description, limit: 500
      t.integer :decimal_precision, null: false, default: 0
      t.string :status, null: false, limit: 12, default: 'active'
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :units_of_measure, 'organization_id, LOWER(code)', unique: true,
              where: 'deleted_at IS NULL', name: 'idx_units_measure_org_code_active'
    add_index :units_of_measure, %i[organization_id status deleted_at],
              name: 'idx_units_measure_org_status'
    add_index :units_of_measure, %i[organization_id sat_unit_key_id],
              name: 'idx_units_measure_org_sat'
    add_check_constraint :units_of_measure, 'decimal_precision BETWEEN 0 AND 6',
                         name: 'chk_units_measure_precision'
    add_check_constraint :units_of_measure, "status IN ('active', 'inactive')",
                         name: 'chk_units_measure_status'
    add_check_constraint :units_of_measure, "code ~ '^[A-Z0-9_]+$'",
                         name: 'chk_units_measure_code_format'
  end
end

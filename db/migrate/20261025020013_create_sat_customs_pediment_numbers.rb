# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatCustomsPedimentNumbers < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_customs_pediment_numbers do |t|
      t.string :code, limit: 40, null: false
      t.string :description, limit: 255, null: false
      t.string :customs_office_code, limit: 5
      t.string :patent_code, limit: 5
      t.integer :fiscal_year
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_customs_pediment_numbers, :code, unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_customs_pediment_numbers_active_key'
    add_index :sat_customs_pediment_numbers, :deleted_at
    add_index :sat_customs_pediment_numbers, %i[valid_from valid_to], name: 'idx_sat_customs_pediment_numbers_validity'
    add_index :sat_customs_pediment_numbers, :customs_office_code, name: 'idx_sat_customs_pediment_numbers_customs_office_code'
    add_index :sat_customs_pediment_numbers, :patent_code, name: 'idx_sat_customs_pediment_numbers_patent_code'
    add_index :sat_customs_pediment_numbers, :fiscal_year, name: 'idx_sat_customs_pediment_numbers_fiscal_year'

    add_check_constraint :sat_customs_pediment_numbers,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_customs_pediment_numbers_validity'
  end
end

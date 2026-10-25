# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatNeighborhoods < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_neighborhoods do |t|
      t.string :code, limit: 5, null: false
      t.string :description, limit: 255, null: false
      t.string :postal_code, limit: 5, null: false
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_neighborhoods, %i[postal_code code], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_neighborhoods_active_key'
    add_index :sat_neighborhoods, :deleted_at
    add_index :sat_neighborhoods, %i[valid_from valid_to], name: 'idx_sat_neighborhoods_validity'
    add_index :sat_neighborhoods, :postal_code, name: 'idx_sat_neighborhoods_postal_code'

    add_check_constraint :sat_neighborhoods,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_neighborhoods_validity'
  end
end

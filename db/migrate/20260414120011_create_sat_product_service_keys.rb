# frozen_string_literal: true

# SAT CFDI 4.0 catalog. Keep historical keys available for dated CFDI validation.
class CreateSatProductServiceKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_product_service_keys do |t|
      t.string :code, limit: 8, null: false
      t.string :description, limit: 500, null: false
      t.boolean :includes_vat
      t.boolean :includes_ieps
      t.string :required_complement, limit: 255
      t.date :valid_from
      t.date :valid_to
      t.boolean :status, null: false, default: true
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :sat_product_service_keys, :code, unique: true,
              where: 'deleted_at IS NULL', name: 'idx_sat_product_service_keys_active_key'
    add_index :sat_product_service_keys, :deleted_at
    add_index :sat_product_service_keys, %i[valid_from valid_to], name: 'idx_sat_product_service_keys_validity'

    add_check_constraint :sat_product_service_keys,
                         'valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from',
                         name: 'chk_sat_product_service_keys_validity'
    add_check_constraint :sat_product_service_keys,
                         "code ~ '^[0-9]{8}$'",
                         name: 'chk_sat_product_service_keys_code_format'
  end
end

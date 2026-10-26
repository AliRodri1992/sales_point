class CreateSatUnitKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_unit_keys do |t|
      t.string :code, null: false, limit: 5
      t.string :description, null: false, limit: 255

      t.string :symbol, limit: 10

      t.timestamp :valid_from
      t.timestamp :valid_to

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :sat_unit_keys, :code, unique: true, where: "deleted_at IS NULL"
    add_index :sat_unit_keys, :valid_from
    add_index :sat_unit_keys, :valid_to
    add_index :sat_unit_keys, :deleted_at

    add_check_constraint :sat_unit_keys,
                         "code = UPPER(code)",
                         name: "chk_sat_unit_keys_upper_code"

    add_check_constraint :sat_unit_keys,
                         "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from",
                         name: "chk_sat_unit_keys_valid_range"
  end
end

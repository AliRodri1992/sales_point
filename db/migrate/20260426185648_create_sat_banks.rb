class CreateSatBanks < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_banks, id: false do |t|
      t.string :code, limit: 3, null: false
      t.string :name, limit: 255, null: false

      t.timestamp :valid_from
      t.timestamp :valid_to
      t.boolean :status, null: false, default: true

      t.timestamps
      t.timestamp :deleted_at
    end

    execute "ALTER TABLE sat_banks ADD PRIMARY KEY (code);"

    add_index :sat_banks,
              :code,
              where: "deleted_at IS NULL AND status = TRUE"

    add_index :sat_banks, :name

    add_index :sat_banks,
              [:valid_from, :valid_to],
              where: "deleted_at IS NULL"

    add_index :sat_banks, :deleted_at

    add_check_constraint :sat_banks,
                         "code ~ '^[0-9]{3}$'",
                         name: "chk_sat_banks_code_format"

    add_check_constraint :sat_banks,
                         "code = TRIM(code)",
                         name: "chk_sat_banks_code_trim"

    add_check_constraint :sat_banks,
                         "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from",
                         name: "chk_sat_banks_validity"
  end
end

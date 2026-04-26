class CreateSatMonths < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_months, id: false do |t|
      t.string :code, limit: 2, null: false
      t.string :description, limit: 50, null: false

      t.integer :month_number, null: false

      t.date :valid_from
      t.date :valid_to

      t.boolean :status, null: false, default: true

      t.timestamps
      t.timestamp :deleted_at
    end

    execute "ALTER TABLE sat_months ADD PRIMARY KEY (code);"

    add_check_constraint :sat_months,
                         "code ~ '^(0[1-9]|1[0-2])$'"

    add_check_constraint :sat_months,
                         "month_number BETWEEN 1 AND 12"

    add_check_constraint :sat_months,
                         "(valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)"

    add_check_constraint :sat_months,
                         "CAST(code AS INTEGER) = month_number"

    add_index :sat_months, :code,
              where: "deleted_at IS NULL AND status = TRUE"

    add_index :sat_months, :month_number,
              where: "deleted_at IS NULL"

    add_index :sat_months, [:valid_from, :valid_to],
              where: "deleted_at IS NULL"

    add_index :sat_months, :deleted_at

    add_index :sat_months, :status
  end
end

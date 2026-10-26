class CreateSatPaymentMethods < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_payment_methods do |t|
      t.string :code, limit: 3, null: false
      t.string :description, limit: 255, null: false

      t.timestamp :valid_from
      t.timestamp :valid_to

      t.boolean :status, default: true, null: false

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :sat_payment_methods, :description

    add_index :sat_payment_methods, [:valid_from, :valid_to], where: "deleted_at IS NULL"

    add_index :sat_payment_methods,
              :code,
              where: "deleted_at IS NULL AND status = TRUE",
              name: "index_sat_payment_methods_active"

    add_index :sat_payment_methods,
              :code,
              unique: true,
              where: "deleted_at IS NULL AND status = TRUE",
              name: "index_sat_payment_methods_unique"

    add_index :sat_payment_methods, :deleted_at

    add_check_constraint :sat_payment_methods,
                         "code ~ '^[0-9]{2}$'",
                         name: "chk_sat_payment_methods_code_format"

    add_check_constraint :sat_payment_methods,
                         "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from",
                         name: "chk_sat_payment_methods_validity"
  end
end

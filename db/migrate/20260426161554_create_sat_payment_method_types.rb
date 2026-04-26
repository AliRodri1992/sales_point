class CreateSatPaymentMethodTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_payment_method_types do |t|
      t.string :code, limit: 3, null: false
      t.string :description, limit: 100, null: false

      t.date :valid_from
      t.date :valid_to

      t.boolean :status, default: true, null: false

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :sat_payment_method_types, :code, unique: true, where: "deleted_at IS NULL"
    add_index :sat_payment_method_types, [:valid_from, :valid_to], where: "deleted_at IS NULL"
    add_index :sat_payment_method_types, :status
    add_index :sat_payment_method_types, :deleted_at

    add_check_constraint :sat_payment_method_types, "code IN ('PUE','PPD')",  name: "chk_sat_payment_method_types_code"
    add_check_constraint :sat_payment_method_types, "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from", name: "chk_sat_payment_method_types_validity"
  end
end

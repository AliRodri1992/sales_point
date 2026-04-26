class CreateSatCurrencies < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_currencies do |t|
      t.string :code, limit: 3, null: false

      t.string :description, null: false, limit: 100

      t.integer :decimals, null: false, default: 2
      t.decimal :variation_percentage, precision: 5, scale: 2
      t.string :symbol, limit: 5

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :sat_currencies, :code, unique: true
    add_index :sat_currencies, :deleted_at

    add_check_constraint :sat_currencies,
                         "code = UPPER(TRIM(code))",
                         name: "chk_sat_currencies_code_uppercase"

    add_check_constraint :sat_currencies,
                         "code ~ '^[A-Z]{3}$'",
                         name: "chk_sat_currencies_code_format"

    add_check_constraint :sat_currencies,
                         "decimals BETWEEN 0 AND 6",
                         name: "chk_sat_currencies_decimals_range"

    add_check_constraint :sat_currencies,
                         "decimals IN (0,2,3,4,5,6,8)",
                         name: "chk_sat_currencies_decimals_allowed"

    add_check_constraint :sat_currencies,
                         "variation_percentage >= 0 OR variation_percentage IS NULL",
                         name: "chk_sat_currencies_variation_positive"
  end
end

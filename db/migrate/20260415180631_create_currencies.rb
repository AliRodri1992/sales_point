class CreateCurrencies < ActiveRecord::Migration[8.1]
  def change
    create_table :currencies do |t|
      t.string :name, null: false, limit: 150
      t.string :code, null: false, limit: 3
      t.string :numeric_code, limit: 3
      t.string :symbol, limit: 12
      t.integer :decimal_places, null: false, default: 2
      t.boolean :active, null: false, default: true

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :currencies, :code, unique: true
    add_index :currencies, :numeric_code, unique: true
    add_index :currencies, :deleted_at
    add_index :currencies, :active

    add_check_constraint :currencies, "code ~ '^[A-Z]{3}$'",
                         name: 'chk_currencies_code'
    add_check_constraint :currencies,
                         "numeric_code IS NULL OR numeric_code ~ '^[0-9]{3}$'",
                         name: 'chk_currencies_numeric_code'
    add_check_constraint :currencies, 'decimal_places BETWEEN 0 AND 8',
                         name: 'chk_currencies_decimal_places'
  end
end

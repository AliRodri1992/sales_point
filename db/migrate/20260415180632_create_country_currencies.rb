class CreateCountryCurrencies < ActiveRecord::Migration[8.1]
  def change
    create_table :country_currencies do |t|
      t.references :country, null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.boolean :is_primary, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :country_currencies, %i[country_id currency_id],
              unique: true, name: 'idx_country_currencies_unique'
    add_index :country_currencies, :country_id,
              unique: true, where: 'is_primary = TRUE',
              name: 'idx_country_currencies_one_primary'
    add_check_constraint :country_currencies,
                         'NOT is_primary OR active',
                         name: 'chk_country_currencies_primary_active'
  end
end

class CreateCountries < ActiveRecord::Migration[8.1]
  def change
    create_table :countries do |t|
      t.string :name, null: false, limit: 150
      t.string :iso_alpha2, null: false, limit: 2
      t.string :iso_alpha3, null: false, limit: 3
      t.string :iso_numeric, null: false, limit: 3
      t.string :phone_code, limit: 10
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :countries, :iso_alpha2, unique: true
    add_index :countries, :iso_alpha3, unique: true
    add_index :countries, :iso_numeric, unique: true
    add_index :countries, :deleted_at
    add_index :countries, %i[active position]

    add_check_constraint :countries, "iso_alpha2 ~ '^[A-Z]{2}$'",
                         name: 'chk_countries_iso_alpha2'
    add_check_constraint :countries, "iso_alpha3 ~ '^[A-Z]{3}$'",
                         name: 'chk_countries_iso_alpha3'
    add_check_constraint :countries, "iso_numeric ~ '^[0-9]{3}$'",
                         name: 'chk_countries_iso_numeric'
    add_check_constraint :countries, 'position >= 0',
                         name: 'chk_countries_position'
  end
end

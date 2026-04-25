class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.string :street, limit: 150
      t.string :exterior_number, limit: 20
      t.string :interior_number, limit: 20
      t.string :neighborhood, limit: 100
      t.string :city, limit: 100
      t.string :state, limit: 100
      t.string :country, null: false, limit: 100
      t.string :postal_code, null: false, limit: 10

      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6

      t.string :geocoding_status, null: false, default: "pending", limit: 20

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :addresses, :deleted_at, where: "deleted_at IS NULL"
    add_index :addresses, :postal_code
    add_index :addresses, :geocoding_status
    add_index :addresses, [:postal_code, :country, :geocoding_status]

    add_check_constraint :addresses,
                         "latitude BETWEEN -90 AND 90 OR latitude IS NULL",
                         name: "check_latitude_range"

    add_check_constraint :addresses,
                         "longitude BETWEEN -180 AND 180 OR longitude IS NULL",
                         name: "check_longitude_range"
  end
end

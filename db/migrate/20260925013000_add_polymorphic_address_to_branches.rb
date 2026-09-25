class AddPolymorphicAddressToBranches < ActiveRecord::Migration[8.1]
  def up
    add_reference :addresses, :addressable, polymorphic: true, index: true

    say_with_time 'Migrating existing branch addresses' do
      execute <<~SQL.squish
        INSERT INTO addresses (
          street,
          country,
          postal_code,
          geocoding_status,
          created_at,
          updated_at,
          addressable_id,
          addressable_type
        )
        SELECT
          branches.address,
          'MX',
          '00000',
          'pending',
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP,
          branches.id,
          'Branch'
        FROM branches
        WHERE branches.address IS NOT NULL
          AND BTRIM(branches.address) <> ''
      SQL
    end

    change_column_null :addresses, :addressable_type, false
    change_column_null :addresses, :addressable_id, false

    add_index :addresses,
              %i[addressable_type addressable_id],
              unique: true,
              name: 'index_addresses_on_addressable_unique'

    remove_column :branches, :address, :string
  end

  def down
    add_column :branches, :address, :string

    execute <<~SQL.squish
      UPDATE branches
      SET address = addresses.street
      FROM addresses
      WHERE addresses.addressable_type = 'Branch'
        AND addresses.addressable_id = branches.id
    SQL

    remove_index :addresses, name: 'index_addresses_on_addressable_unique'
    remove_reference :addresses, :addressable, polymorphic: true
  end
end

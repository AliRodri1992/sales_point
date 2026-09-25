class AddPolymorphicAddressToBranches < ActiveRecord::Migration[8.1]
  def up
    add_reference :addresses, :addressable, polymorphic: true, index: false

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

    orphan_count = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*)
      FROM addresses
      WHERE addressable_id IS NULL
         OR addressable_type IS NULL
    SQL

    if orphan_count.positive?
      raise ActiveRecord::MigrationError,
            'Cannot make addresses polymorphic: existing addresses are not associated with an addressable record.'
    end

    change_column_null :addresses, :addressable_type, false
    change_column_null :addresses, :addressable_id, false

    add_index :addresses,
              %i[addressable_type addressable_id],
              unique: true,
              name: 'index_addresses_on_addressable_unique'

    remove_column :branches, :address, :string

    null_name_count = select_value('SELECT COUNT(*) FROM branches WHERE name IS NULL').to_i

    if null_name_count.positive?
      raise ActiveRecord::MigrationError,
            'Cannot enforce branches.name NOT NULL: existing branches contain a NULL name.'
    end

    execute 'UPDATE branches SET status = TRUE WHERE status IS NULL'
    change_column_default :branches, :status, from: nil, to: true
    change_column_null :branches, :name, false
    change_column_null :branches, :status, false
  end

  def down
    change_column_null :branches, :status, true
    change_column_default :branches, :status, from: true, to: nil
    change_column_null :branches, :name, true

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

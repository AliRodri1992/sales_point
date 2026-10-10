# frozen_string_literal: true

class AllowPrimaryAddressesPerPurpose < ActiveRecord::Migration[8.1]
  def change
    remove_index :addresses, name: 'idx_addresses_one_active_primary'
    add_index :addresses, %i[addressable_type addressable_id purpose], unique: true,
              where: 'deleted_at IS NULL AND "primary" = TRUE',
              name: 'idx_addresses_one_primary_per_purpose'
  end
end

# frozen_string_literal: true

class AddSupplierAddressMetadata < ActiveRecord::Migration[8.1]
  def change
    add_column :addresses, :primary, :boolean, default: false, null: false
    add_column :addresses, :purpose, :string, limit: 30, default: 'general', null: false

    add_check_constraint :addresses,
                         "purpose IN ('general', 'fiscal', 'commercial', 'delivery')",
                         name: 'chk_addresses_purpose'

    add_index :addresses, %i[addressable_type addressable_id],
              unique: true,
              where: 'deleted_at IS NULL AND "primary" = TRUE',
              name: 'idx_addresses_one_active_primary'
  end
end

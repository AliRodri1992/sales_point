# frozen_string_literal: true

class CreateOrganizationSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_settings do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :base_currency, null: false, foreign_key: { to_table: :currencies }
      t.string :timezone, null: false, default: 'UTC'
      t.string :payment_method, null: false, default: 'cash', limit: 20
      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :organization_settings, :deleted_at
    add_index :organization_settings, :organization_id, unique: true, where: 'deleted_at IS NULL',
              name: 'idx_organization_settings_active_org'
    add_check_constraint :organization_settings,
                         "payment_method IN ('cash', 'card', 'qr')",
                         name: 'check_organization_settings_payment_method'
  end
end

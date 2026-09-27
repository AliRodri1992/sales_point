# frozen_string_literal: true

class CreatePermissionsAndSystemRolePermissions < ActiveRecord::Migration[8.1]
  # rubocop:disable-next Metrics/MethodLength,Metrics/AbcSize
  def change
    create_table :permissions do |t|
      t.string :code, null: false, limit: 80
      t.string :name, null: false, limit: 80
      t.string :module_name, null: false, limit: 50
      t.string :description
      t.string :status, null: false, default: 'active', limit: 20
      t.timestamp :deleted_at

      t.timestamps
    end

    add_index :permissions, :code, unique: true
    add_index :permissions, :status
    add_index :permissions, %i[module_name status]
    add_index :permissions, :deleted_at
    add_index :permissions, %i[deleted_at status]

    add_check_constraint :permissions,
                         "status IN ('active', 'inactive')",
                         name: 'check_permissions_status'

    create_table :system_role_permissions do |t|
      t.references :system_role, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.timestamp :deleted_at

      t.timestamps
    end

    add_index :system_role_permissions,
              %i[system_role_id permission_id],
              unique: true,
              name: 'idx_system_role_permissions_unique'
    add_index :system_role_permissions, :deleted_at
  end
end

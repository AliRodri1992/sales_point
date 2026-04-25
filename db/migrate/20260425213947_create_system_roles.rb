class CreateSystemRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :system_roles do |t|
      t.string :name, null: false, limit: 50
      t.string :description

      t.string :role_type, null: false, limit: 20
      t.string :status, null: false, default: "active", limit: 20

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :system_roles, [:name, :role_type], unique: true
    add_index :system_roles, [:role_type, :status]
    add_index :system_roles, :created_at
    add_index :system_roles, :deleted_at

    add_check_constraint :system_roles,
                         "role_type IN ('system', 'branch')",
                         name: "check_system_roles_role_type"

    add_check_constraint :system_roles,
                         "status IN ('active', 'inactive', 'deprecated')",
                         name: "check_system_roles_status"

    add_check_constraint :system_roles,
                         "(deleted_at IS NULL AND status != 'deprecated') OR (deleted_at IS NOT NULL)",
                         name: "check_system_roles_deleted_status"
  end
end

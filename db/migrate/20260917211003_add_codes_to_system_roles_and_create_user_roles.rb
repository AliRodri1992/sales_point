# frozen_string_literal: true

class AddCodesToSystemRolesAndCreateUserRoles < ActiveRecord::Migration[8.1]
  def change
    add_column :system_roles, :code, :string, limit: 50
    add_index :system_roles, :code, unique: true

    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :system_role, null: false, foreign_key: true
      t.references :branch, null: true, foreign_key: true

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :user_roles, :deleted_at
    add_index :user_roles,
              %i[user_id system_role_id],
              unique: true,
              where: 'deleted_at IS NULL AND branch_id IS NULL',
              name: 'idx_user_roles_global_unique'
    add_index :user_roles,
              %i[user_id system_role_id branch_id],
              unique: true,
              where: 'deleted_at IS NULL AND branch_id IS NOT NULL',
              name: 'idx_user_roles_branch_unique'
  end
end

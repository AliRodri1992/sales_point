# frozen_string_literal: true

class AddCaseInsensitiveSystemRoleNameIndex < ActiveRecord::Migration[8.1]
  def up
    add_index :system_roles, 'LOWER(BTRIM(name)), role_type',
              unique: true, name: 'idx_system_roles_normalized_name_type'
  end

  def down
    remove_index :system_roles, name: 'idx_system_roles_normalized_name_type'
  end
end

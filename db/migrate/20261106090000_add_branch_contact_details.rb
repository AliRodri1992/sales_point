# frozen_string_literal: true

class AddBranchContactDetails < ActiveRecord::Migration[8.1]
  def change
    change_table :branches, bulk: true do |table|
      table.string :code, limit: 30
      table.string :contact_email, limit: 254
    end
    add_index :branches, 'organization_id, lower(code)', unique: true,
                                                         where: 'deleted_at IS NULL AND code IS NOT NULL',
                                                         name: 'idx_branches_org_code_active'
    add_check_constraint :branches, "code IS NULL OR code ~ '^[A-Z0-9_-]{1,30}$'", name: 'branches_valid_code'
  end
end

# frozen_string_literal: true

class CreateOrganizationMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'active', limit: 20
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :organization_memberships, :deleted_at
    add_index :organization_memberships, [:organization_id, :user_id], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_org_memberships_active_unique'
    add_check_constraint :organization_memberships,
                         "status IN ('active', 'inactive')",
                         name: 'check_org_memberships_status'
  end
end
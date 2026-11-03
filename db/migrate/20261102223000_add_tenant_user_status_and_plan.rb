# frozen_string_literal: true

class AddTenantUserStatusAndPlan < ActiveRecord::Migration[8.1]
  def up
    add_reference :organizations, :membership_plan, null: true, foreign_key: true
    add_column :organization_memberships, :account_status, :string, default: 'active', null: false
    add_column :organization_memberships, :status_review_at, :datetime
    execute <<~SQL.squish
      UPDATE organization_memberships AS memberships
      SET account_status = users.status
      FROM users
      WHERE memberships.user_id = users.id
        AND users.status IN ('pending', 'suspended', 'blocked', 'deleted')
    SQL
    add_check_constraint :organization_memberships,
                         "account_status IN ('pending', 'active', 'suspended', 'blocked', 'deleted')",
                         name: 'chk_org_member_account_status'
    add_index :organization_memberships, [:organization_id, :account_status],
              name: 'idx_org_memberships_account_status',
              where: "deleted_at IS NULL AND status = 'active'"
  end

  def down
    remove_index :organization_memberships, name: 'idx_org_memberships_account_status'
    remove_check_constraint :organization_memberships, name: 'chk_org_member_account_status'
    remove_column :organization_memberships, :status_review_at
    remove_column :organization_memberships, :account_status
    remove_reference :organizations, :membership_plan, foreign_key: true
  end
end

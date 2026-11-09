# frozen_string_literal: true

class OptimizeOperationalQueryIndexes < ActiveRecord::Migration[8.1]
  # Build and retire indexes without holding prolonged write locks.
  disable_ddl_transaction!

  def up
    add_index :email_templates, :published_version_id,
              name: 'idx_email_templates_published_version',
              algorithm: :concurrently, if_not_exists: true
    add_index :user_roles, %i[system_role_id branch_id user_id],
              where: 'deleted_at IS NULL', name: 'idx_user_roles_active_role_branch_user',
              algorithm: :concurrently, if_not_exists: true
    add_index :branches, %i[organization_id created_at],
              where: 'deleted_at IS NULL', name: 'idx_branches_active_org_created_at',
              algorithm: :concurrently, if_not_exists: true

    # These two indexes are covered by identical-key unique indexes. Keep
    # the unique indexes because they enforce business invariants.
    remove_index :sat_payment_methods, name: 'index_sat_payment_methods_active',
                 algorithm: :concurrently, if_exists: true
    remove_index :purchase_cost_allocations,
                 name: 'index_purchase_cost_allocations_on_goods_receipt_item_id',
                 algorithm: :concurrently, if_exists: true
  end

  def down
    add_index :purchase_cost_allocations, :goods_receipt_item_id,
              name: 'index_purchase_cost_allocations_on_goods_receipt_item_id',
              algorithm: :concurrently, if_not_exists: true
    add_index :sat_payment_methods, :code,
              where: 'deleted_at IS NULL AND status = TRUE',
              name: 'index_sat_payment_methods_active',
              algorithm: :concurrently, if_not_exists: true

    remove_index :branches, name: 'idx_branches_active_org_created_at',
                 algorithm: :concurrently, if_exists: true
    remove_index :user_roles, name: 'idx_user_roles_active_role_branch_user',
                 algorithm: :concurrently, if_exists: true
    remove_index :email_templates, name: 'idx_email_templates_published_version',
                 algorithm: :concurrently, if_exists: true
  end
end

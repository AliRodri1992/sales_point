# frozen_string_literal: true

class AddBranchOperationalLifecycle < ActiveRecord::Migration[8.1]
  def up
    add_column :branches, :operational_status, :string, default: 'preparing', null: false
    add_index :branches, %i[organization_id operational_status], name: 'idx_branches_organization_operational_status'
    execute <<~SQL
      UPDATE branches
      SET operational_status = CASE WHEN status IS TRUE THEN 'active' ELSE 'suspended' END
    SQL
    add_check_constraint :branches,
                         "operational_status IN ('preparing', 'active', 'suspended', 'closed')",
                         name: 'branches_operational_status_valid'

    create_table :branch_status_transitions do |t|
      t.references :branch, null: false, foreign_key: true, index: true
      t.references :changed_by, foreign_key: { to_table: :users }, index: true
      t.string :from_status
      t.string :to_status, null: false
      t.text :reason
      t.timestamps
    end
    add_index :branch_status_transitions, %i[branch_id created_at], name: 'idx_branch_status_transitions_chronological'
  end

  def down
    drop_table :branch_status_transitions
    remove_check_constraint :branches, name: 'branches_operational_status_valid'
    remove_index :branches, name: 'idx_branches_organization_operational_status'
    remove_column :branches, :operational_status
  end
end

# frozen_string_literal: true

class BackfillInitialBranchStatusTransitions < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO branch_status_transitions
        (branch_id, from_status, to_status, created_at, updated_at)
      SELECT branches.id, NULL, branches.operational_status,
             branches.created_at, branches.created_at
      FROM branches
      WHERE NOT EXISTS (
        SELECT 1 FROM branch_status_transitions
        WHERE branch_status_transitions.branch_id = branches.id
      )
    SQL
  end

  def down
    # Historical audit events are intentionally retained.
  end
end

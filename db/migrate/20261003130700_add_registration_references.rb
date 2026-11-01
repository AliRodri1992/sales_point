# frozen_string_literal: true

class AddRegistrationReferences < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :employee, foreign_key: true, null: true
    add_column :users, :terms_accepted_at, :datetime

    add_reference :branches, :organization, foreign_key: true, null: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX idx_branches_org_name_active
          ON branches (organization_id, LOWER(name))
          WHERE organization_id IS NOT NULL AND deleted_at IS NULL
        SQL
      end

      dir.down do
        execute 'DROP INDEX IF EXISTS idx_branches_org_name_active'
      end
    end
  end
end

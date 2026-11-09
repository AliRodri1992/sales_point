# frozen_string_literal: true

# Roles are granted within an organization, not inherited by future memberships.
# Preserve already-effective legacy grants in each existing membership.
class ScopeUserRolesByOrganization < ActiveRecord::Migration[8.1]
  def up
    add_reference :user_roles, :organization, null: true, foreign_key: true

    execute <<~SQL
      UPDATE user_roles
      SET organization_id = branches.organization_id
      FROM branches
      WHERE user_roles.branch_id = branches.id
    SQL

    remove_index :user_roles, name: 'idx_user_roles_global_unique'

    execute <<~SQL
      UPDATE user_roles
      SET organization_id = membership.organization_id
      FROM (
        SELECT DISTINCT ON (user_id) user_id, organization_id
        FROM organization_memberships
        WHERE deleted_at IS NULL AND status = 'active'
        ORDER BY user_id, organization_id
      ) membership
      WHERE user_roles.user_id = membership.user_id
        AND user_roles.branch_id IS NULL
        AND user_roles.organization_id IS NULL
    SQL

    execute <<~SQL
      INSERT INTO user_roles (user_id, system_role_id, branch_id, organization_id,
                              created_at, updated_at, deleted_at)
      SELECT DISTINCT source.user_id, source.system_role_id, NULL::bigint, memberships.organization_id,
                      source.created_at, source.updated_at, NULL::timestamp
      FROM user_roles source
      JOIN organization_memberships memberships ON memberships.user_id = source.user_id
      WHERE source.branch_id IS NULL AND source.deleted_at IS NULL
        AND source.organization_id IS NOT NULL
        AND memberships.deleted_at IS NULL AND memberships.status = 'active'
        AND memberships.organization_id <> source.organization_id
        AND NOT EXISTS (
          SELECT 1 FROM user_roles existing
          WHERE existing.user_id = source.user_id
            AND existing.system_role_id = source.system_role_id
            AND existing.organization_id = memberships.organization_id
            AND existing.branch_id IS NULL AND existing.deleted_at IS NULL
        )
    SQL

    add_index :user_roles, %i[user_id system_role_id organization_id],
              unique: true, where: 'deleted_at IS NULL AND branch_id IS NULL AND organization_id IS NOT NULL',
              name: 'idx_user_roles_organization_unique'
    add_index :user_roles, %i[user_id system_role_id],
              unique: true, where: 'deleted_at IS NULL AND branch_id IS NULL AND organization_id IS NULL',
              name: 'idx_user_roles_unassigned_unique'
    add_index :user_roles, %i[organization_id user_id],
              name: 'idx_user_roles_tenant_user', where: 'deleted_at IS NULL'
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Organization-specific role grants cannot safely be merged'
  end
end

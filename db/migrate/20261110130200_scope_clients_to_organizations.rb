# frozen_string_literal: true

# Preserve legacy clients without reliable tenant evidence. Never infer an
# owner from RFC, name, the logged-in user or the first organization.
class ScopeClientsToOrganizations < ActiveRecord::Migration[8.1]
  def up
    add_reference :clients, :organization, null: true, foreign_key: true, index: false
    backfill_unambiguous_owners!
    replace_unique_indexes!
    add_index :clients, %i[organization_id status deleted_at], name: 'idx_clients_org_status'
    add_index :clients, %i[organization_id created_at], name: 'idx_clients_org_created_at'
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Tenant ownership cannot safely be reverted to globally shared client records'
  end

  private

  def backfill_unambiguous_owners!
    execute <<~SQL.squish
      WITH evidence AS (
        SELECT phoneable_id AS client_id, organization_id
        FROM phones WHERE phoneable_type = 'Client' AND organization_id IS NOT NULL
        UNION ALL
        SELECT notable_id AS client_id, organization_id
        FROM notes WHERE notable_type = 'Client' AND organization_id IS NOT NULL
      ), confirmed AS (
        SELECT client_id, MIN(organization_id) AS organization_id
        FROM evidence
        GROUP BY client_id
        HAVING COUNT(DISTINCT organization_id) = 1
      )
      UPDATE clients SET organization_id = confirmed.organization_id
      FROM confirmed WHERE clients.id = confirmed.client_id AND clients.organization_id IS NULL
    SQL
  end

  def replace_unique_indexes!
    remove_index :clients, name: 'index_clients_on_code'
    remove_index :clients, name: 'index_clients_on_rfc'
    add_index :clients, %i[organization_id code], unique: true,
              where: 'deleted_at IS NULL AND organization_id IS NOT NULL',
              name: 'idx_clients_org_code_active'
    add_index :clients, %i[organization_id rfc], unique: true,
              where: "deleted_at IS NULL AND organization_id IS NOT NULL AND rfc IS NOT NULL AND rfc <> ''",
              name: 'idx_clients_org_rfc_active'
    add_index :clients, :code, unique: true,
              where: 'deleted_at IS NULL AND organization_id IS NULL',
              name: 'idx_clients_unassigned_code'
    add_index :clients, :rfc, unique: true,
              where: "deleted_at IS NULL AND organization_id IS NULL AND rfc IS NOT NULL AND rfc <> ''",
              name: 'idx_clients_unassigned_rfc'
  end
end

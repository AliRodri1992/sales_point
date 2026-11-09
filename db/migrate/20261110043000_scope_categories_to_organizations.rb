# frozen_string_literal: true

# Preserve historical category IDs while giving every existing organization
# its own editable copy. No global row is destroyed: legacy rows are retired.
class ScopeCategoriesToOrganizations < ActiveRecord::Migration[8.1]
  def up
    add_reference :categories, :organization, null: true, foreign_key: true, index: false
    remove_index :categories, name: 'index_categories_on_code'
    add_index :categories, %i[organization_id code], unique: true,
              where: 'deleted_at IS NULL AND organization_id IS NOT NULL',
              name: 'idx_categories_organization_code'
    add_index :categories, :code, unique: true,
              where: 'deleted_at IS NULL AND organization_id IS NULL',
              name: 'idx_categories_legacy_code'

    invalid_count = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM categories WHERE organization_id IS NULL AND deleted_at IS NULL
        AND (name IS NULL OR btrim(name) = '' OR code !~ '^[a-z0-9_]{1,20}$'
             OR code IS NULL OR status IS NULL OR status NOT IN ('active', 'inactive'))
    SQL
    raise 'Cannot migrate categories with invalid legacy values; clean them before retrying' if invalid_count.positive?

    execute <<~SQL
      INSERT INTO categories (organization_id, name, code, description, status, created_at, updated_at, deleted_at)
      SELECT org.id, base.name, base.code, base.description, base.status, base.created_at, base.updated_at, NULL
      FROM organizations AS org
      CROSS JOIN categories AS base
      WHERE base.organization_id IS NULL AND base.deleted_at IS NULL
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      UPDATE products AS product SET category_id = owned.id
      FROM categories AS base, categories AS owned
      WHERE product.category_id = base.id AND base.organization_id IS NULL
        AND owned.organization_id = product.organization_id AND owned.code = base.code
        AND owned.deleted_at IS NULL
    SQL
    execute <<~SQL
      UPDATE promotion_conditions AS condition SET category_id = owned.id
      FROM categories AS base, categories AS owned
      WHERE condition.category_id = base.id AND base.organization_id IS NULL
        AND owned.organization_id = condition.organization_id AND owned.code = base.code
        AND owned.deleted_at IS NULL
    SQL

    # Historical rows remain for audit/noticed references, but never participate
    # in ordinary catalog writes or listing after backfill.
    execute <<~SQL
      UPDATE categories SET deleted_at = CURRENT_TIMESTAMP
      WHERE organization_id IS NULL AND deleted_at IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Tenant-specific category edits cannot safely be folded into the old global catalog'
  end
end

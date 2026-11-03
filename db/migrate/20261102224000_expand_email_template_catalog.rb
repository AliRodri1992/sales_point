# frozen_string_literal: true

class ExpandEmailTemplateCatalog < ActiveRecord::Migration[8.1]
  def up
    add_reference :email_templates, :organization, null: true, foreign_key: true
    add_column :email_templates, :name, :string
    add_column :email_templates, :category, :string, null: false, default: 'transactional'
    add_column :email_templates, :status, :string, null: false, default: 'published'
    add_reference :email_templates, :created_by, null: true, foreign_key: { to_table: :users }
    add_reference :email_templates, :updated_by, null: true, foreign_key: { to_table: :users }
    add_column :email_templates, :published_version_id, :bigint

    remove_index :email_templates, name: 'index_email_templates_on_key_and_locale'
    add_index :email_templates, [:key, :locale], unique: true,
              where: 'organization_id IS NULL', name: 'idx_email_templates_global_unique'
    add_index :email_templates, [:organization_id, :key, :locale], unique: true,
              where: 'organization_id IS NOT NULL', name: 'idx_email_templates_tenant_unique'
    add_index :email_templates, [:organization_id, :status, :updated_at],
              name: 'idx_email_templates_tenant_status'

    execute <<~SQL.squish
      UPDATE email_templates SET name = key WHERE name IS NULL
    SQL
    change_column_null :email_templates, :name, false
    add_check_constraint :email_templates,
                         "status IN ('draft', 'published', 'inactive', 'archived')",
                         name: 'chk_email_templates_status'
  end

  def down
    remove_check_constraint :email_templates, name: 'chk_email_templates_status'
    remove_index :email_templates, name: 'idx_email_templates_tenant_status'
    remove_index :email_templates, name: 'idx_email_templates_tenant_unique'
    remove_index :email_templates, name: 'idx_email_templates_global_unique'
    execute 'DELETE FROM email_templates WHERE organization_id IS NOT NULL'
    add_index :email_templates, [:key, :locale], unique: true,
              name: 'index_email_templates_on_key_and_locale'
    remove_column :email_templates, :published_version_id
    remove_reference :email_templates, :updated_by, foreign_key: { to_table: :users }
    remove_reference :email_templates, :created_by, foreign_key: { to_table: :users }
    remove_column :email_templates, :status
    remove_column :email_templates, :category
    remove_column :email_templates, :name
    remove_reference :email_templates, :organization, foreign_key: true
  end
end

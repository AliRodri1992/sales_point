# frozen_string_literal: true

class CreateEmailTemplateVersions < ActiveRecord::Migration[8.1]
  def up
    create_table :email_template_versions do |t|
      t.references :email_template, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :status, null: false, default: 'draft'
      t.string :subject, null: false
      t.string :preheader, null: false, default: ''
      t.text :html_body, null: false
      t.text :text_body, null: false
      t.jsonb :allowed_variables, null: false, default: []
      t.references :created_by, null: true, foreign_key: { to_table: :users }
      t.references :published_by, null: true, foreign_key: { to_table: :users }
      t.datetime :published_at
      t.timestamps
    end
    add_index :email_template_versions, [:email_template_id, :version_number],
              unique: true, name: 'idx_email_template_versions_number'
    add_index :email_template_versions, [:email_template_id, :status],
              name: 'idx_email_template_versions_status'
    add_check_constraint :email_template_versions,
                         "status IN ('draft', 'published', 'archived')",
                         name: 'chk_email_template_versions_status'
    add_foreign_key :email_templates, :email_template_versions,
                    column: :published_version_id, on_delete: :nullify

    execute <<~SQL.squish
      INSERT INTO email_template_versions
        (email_template_id, version_number, status, subject, html_body, text_body,
         allowed_variables, published_at, created_at, updated_at)
      SELECT id, version, 'published', subject, html_body, text_body,
             '[]'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM email_templates
    SQL
    execute <<~SQL.squish
      UPDATE email_templates SET published_version_id = versions.id
      FROM email_template_versions versions
      WHERE versions.email_template_id = email_templates.id
    SQL
  end

  def down
    remove_foreign_key :email_templates, column: :published_version_id
    drop_table :email_template_versions
  end
end

# frozen_string_literal: true

class CreateEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :email_templates do |t|
      t.string :key, null: false
      t.string :locale, null: false, default: 'es'
      t.string :subject, null: false
      t.text :html_body, null: false
      t.text :text_body, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :version, null: false, default: 1
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :email_templates, [:key, :locale], unique: true
    add_index :email_templates, [:locale, :enabled],
              where: 'deleted_at IS NULL',
              name: 'idx_email_templates_available_locale'
  end
end

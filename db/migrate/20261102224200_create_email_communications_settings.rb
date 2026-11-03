# frozen_string_literal: true

class CreateEmailCommunicationsSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :email_branding_settings do |t|
      t.references :organization, null: true, foreign_key: true
      t.string :display_name, null: false, default: 'Delta POS'
      t.string :primary_color, null: false, default: '#064e3b'
      t.string :secondary_color, null: false, default: '#047857'
      t.string :button_color, null: false, default: '#047857'
      t.string :support_email
      t.string :support_url
      t.string :privacy_url
      t.text :footer_text
      t.timestamps
    end
    add_index :email_branding_settings, :organization_id, unique: true,
              where: 'organization_id IS NOT NULL', name: 'idx_email_branding_tenant_unique'
    add_index :email_branding_settings, '((organization_id IS NULL))', unique: true,
              where: 'organization_id IS NULL', name: 'idx_email_branding_one_global'

    create_table :email_sender_settings do |t|
      t.references :organization, null: true, foreign_key: true
      t.string :display_name, null: false, default: 'Delta POS'
      t.string :from_address
      t.string :reply_to
      t.string :default_locale, null: false, default: 'es'
      t.string :domain
      t.string :domain_status, null: false, default: 'unverified'
      t.timestamps
    end
    add_index :email_sender_settings, :organization_id, unique: true,
              where: 'organization_id IS NOT NULL', name: 'idx_email_senders_tenant_unique'
    add_index :email_sender_settings, '((organization_id IS NULL))', unique: true,
              where: 'organization_id IS NULL', name: 'idx_email_senders_one_global'

    create_table :email_template_audits do |t|
      t.references :email_template, null: false, foreign_key: true
      t.references :email_template_version, null: true, foreign_key: true
      t.references :organization, null: true, foreign_key: true
      t.references :actor, null: true, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :email_template_audits, [:email_template_id, :created_at],
              name: 'idx_email_template_audits_history'
    add_index :email_template_audits, [:organization_id, :created_at],
              name: 'idx_email_template_audits_tenant'
  end
end

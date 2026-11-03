# frozen_string_literal: true

class CreateEmailSettingAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :email_setting_audits do |t|
      t.references :organization, foreign_key: true, null: true
      t.references :actor, foreign_key: { to_table: :users }, null: false
      t.string :setting_type, null: false
      t.jsonb :changeset, default: {}, null: false
      t.timestamps
    end

    add_index :email_setting_audits, %i[organization_id created_at],
              name: 'idx_email_setting_audits_tenant_history'
    add_check_constraint :email_setting_audits,
                         "setting_type IN ('branding', 'sender')",
                         name: 'chk_email_setting_audit_type'
  end
end

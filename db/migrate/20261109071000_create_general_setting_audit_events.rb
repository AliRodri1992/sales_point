# frozen_string_literal: true

class CreateGeneralSettingAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :general_setting_audit_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.integer :previous_page_size, null: false
      t.integer :new_page_size, null: false
      t.timestamp :deleted_at
      t.timestamps

      t.index %i[organization_id created_at], name: 'idx_general_setting_audits_org_created'
      t.index :deleted_at
      t.check_constraint 'previous_page_size IN (5, 10, 15, 25, 50)',
                         name: 'chk_general_settings_audits_previous'
      t.check_constraint 'new_page_size IN (5, 10, 15, 25, 50)',
                         name: 'chk_general_settings_audits_new'
    end
  end
end

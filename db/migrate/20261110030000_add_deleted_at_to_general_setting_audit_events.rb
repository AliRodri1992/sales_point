# frozen_string_literal: true

# Repair audit tables built before ApplicationRecord's soft-delete column was added.
class AddDeletedAtToGeneralSettingAuditEvents < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:general_setting_audit_events, :deleted_at)
      add_column :general_setting_audit_events, :deleted_at, :timestamp
    end

    return if index_exists?(:general_setting_audit_events, :deleted_at)

    add_index :general_setting_audit_events, :deleted_at
  end
end

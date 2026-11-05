# frozen_string_literal: true

class AddDeletedAtToEmailSettingAudits < ActiveRecord::Migration[8.1]
  def change
    add_column :email_setting_audits, :deleted_at, :datetime
  end
end

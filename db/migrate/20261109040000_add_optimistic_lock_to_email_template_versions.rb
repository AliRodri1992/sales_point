# frozen_string_literal: true

class AddOptimisticLockToEmailTemplateVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :email_template_versions, :lock_version, :integer, null: false, default: 0
  end
end

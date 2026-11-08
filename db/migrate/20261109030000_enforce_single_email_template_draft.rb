# frozen_string_literal: true

class EnforceSingleEmailTemplateDraft < ActiveRecord::Migration[8.1]
  def change
    add_index :email_template_versions, :email_template_id,
              unique: true, where: "status = 'draft'",
              name: 'idx_email_template_versions_single_draft'
  end
end

# frozen_string_literal: true

class EnforceSingleEmailTemplateDraft < ActiveRecord::Migration[8.1]
  def up
    # Preserve historical drafts as archived versions before enforcing one active draft.
    execute <<~SQL.squish
      WITH ranked_drafts AS (
        SELECT id, ROW_NUMBER() OVER (
          PARTITION BY email_template_id ORDER BY version_number DESC, id DESC
        ) AS rank
        FROM email_template_versions
        WHERE status = 'draft'
      )
      UPDATE email_template_versions
      SET status = 'archived', updated_at = CURRENT_TIMESTAMP
      WHERE id IN (SELECT id FROM ranked_drafts WHERE rank > 1)
    SQL

    add_index :email_template_versions, :email_template_id,
              unique: true, where: "status = 'draft'",
              name: 'idx_email_template_versions_single_draft'
  end

  def down
    remove_index :email_template_versions, name: 'idx_email_template_versions_single_draft'
  end
end

# frozen_string_literal: true

class BackfillSupplierDocuments < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO supplier_documents (
        supplier_id, attachment_id, series_id, revision_number,
        current_version, category, status, description, created_at, updated_at
      )
      SELECT attachment.record_id, attachment.id, 'legacy-' || attachment.id::text, 1,
             TRUE, 'other', 'active', NULL, attachment.created_at, CURRENT_TIMESTAMP
      FROM active_storage_attachments attachment
      WHERE attachment.record_type = 'Supplier' AND attachment.name = 'documents'
      ON CONFLICT (attachment_id) DO NOTHING
    SQL
  end

  def down
    # Historical attachment metadata is not destroyed by rolling back a backfill.
  end
end

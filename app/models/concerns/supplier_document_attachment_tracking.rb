# frozen_string_literal: true

# Register each supplier attachment when it is committed, never while rendering
# the dossier. Existing attachments are migrated by BackfillSupplierDocuments.
module SupplierDocumentAttachmentTracking
  extend ActiveSupport::Concern

  included do
    after_create_commit :track_supplier_attachment
  end

  private

  def track_supplier_attachment
    return unless record_type == 'Supplier' && name == 'documents'

    SupplierDocument.import_existing!(record)
  end
end
